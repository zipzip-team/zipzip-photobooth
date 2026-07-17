import AVFoundation
import AppKit
import CoreImage

enum CameraAuthorizationState {
    case unknown
    case authorized
    case denied

    var message: String {
        switch self {
        case .unknown:
            return "카메라 권한 확인 중"
        case .authorized:
            return ""
        case .denied:
            return "카메라 권한이 필요합니다"
        }
    }
}

final class CameraModel: NSObject, ObservableObject, @unchecked Sendable {
    let session = AVCaptureSession()

    @Published var capturedImage: NSImage?
    @Published var authorizationState: CameraAuthorizationState = .unknown

    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "PhotoPrintBooth.CameraSession")
    private let videoQueue = DispatchQueue(label: "PhotoPrintBooth.VideoFrames")
    private let frameLock = NSLock()
    private let frameContext = CIContext()
    private var latestPixelBuffer: CVPixelBuffer?

    func requestAndStart() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            await MainActor.run { authorizationState = .authorized }
            configureAndStart()
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { authorizationState = granted ? .authorized : .denied }
            if granted {
                configureAndStart()
            }
        default:
            await MainActor.run { authorizationState = .denied }
        }
    }

    func capturePhoto(orientation: PrintOrientation) {
        frameLock.lock()
        let pixelBuffer = latestPixelBuffer
        frameLock.unlock()

        guard let pixelBuffer else { return }

        let frame = CIImage(cvPixelBuffer: pixelBuffer).oriented(.upMirrored)
        guard let cgImage = frameContext.createCGImage(frame, from: frame.extent) else { return }

        let image = NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
        capturedImage = ImageProcessor.croppedToRatio(image: image, ratio: orientation.ratio) ?? image
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            defer {
                self.session.commitConfiguration()
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }

            guard self.session.inputs.isEmpty else { return }
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  self.session.canAddInput(input) else {
                Task { @MainActor in self.authorizationState = .denied }
                return
            }

            self.session.addInput(input)

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)

                if let connection = self.videoOutput.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = false
                }
            }
        }
    }
}

extension CameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        frameLock.lock()
        latestPixelBuffer = pixelBuffer
        frameLock.unlock()
    }
}
