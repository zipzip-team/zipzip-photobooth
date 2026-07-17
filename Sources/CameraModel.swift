import AVFoundation
import AppKit

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

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "PhotoPrintBooth.CameraSession")
    private var pendingOrientation: PrintOrientation = .landscape

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
        pendingOrientation = orientation
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        output.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

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

            if self.session.canAddOutput(self.output) {
                self.session.addOutput(self.output)
                self.output.maxPhotoQualityPrioritization = .quality
            }
        }
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = NSImage(data: data) else { return }

        Task { @MainActor in
            let mirrored = ImageProcessor.mirrored(image: image) ?? image
            self.capturedImage = ImageProcessor.croppedToRatio(image: mirrored, ratio: self.pendingOrientation.ratio) ?? mirrored
        }
    }
}
