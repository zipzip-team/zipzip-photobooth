import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

enum BoothFilter: String, CaseIterable, Identifiable {
    case orangeLogo
    case whiteLogo
    case house
    case digiCam

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orangeLogo: return "Orange_logo"
        case .whiteLogo: return "White_logo"
        case .house: return "House"
        case .digiCam: return "digi_cam"
        }
    }

    var overlayFilename: String? {
        switch self {
        case .orangeLogo:
            return "orange_logo.png"
        case .whiteLogo:
            return "white_logo.png"
        case .house:
            return "new-house-frame.svg"
        case .digiCam:
            return "digi.png"
        }
    }

    var previewFill: Color {
        switch self {
        case .orangeLogo:
            return Color(red: 0.90, green: 0.90, blue: 0.88)
        case .whiteLogo:
            return Color(red: 0.36, green: 0.36, blue: 0.36)
        case .house:
            return Color(red: 0.66, green: 0.48, blue: 0.34)
        case .digiCam:
            return Color(red: 0.34, green: 0.43, blue: 0.58)
        }
    }
}

struct FilteredImageView: View {
    let image: NSImage
    let filter: BoothFilter

    var body: some View {
        ZStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()

            FilterOverlayView(filter: filter)
        }
    }
}

struct FilterOverlayView: View {
    let filter: BoothFilter

    var body: some View {
        if let filename = filter.overlayFilename,
           let image = ResourceImage.loadFilter(named: filename) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}

enum ResourceImage {
    static func loadFilter(named filename: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Filters") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    static func load(named name: String, ext: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return NSImage(contentsOf: url)
        }

        guard let resourcesURL = Bundle.main.resourceURL,
              let match = try? FileManager.default.contentsOfDirectory(at: resourcesURL, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension.lowercased() == ext.lowercased() && $0.deletingPathExtension().lastPathComponent.contains("사진찍기") }) else {
            return nil
        }
        return NSImage(contentsOf: match)
    }
}

enum ImageProcessor {
    private static let context = CIContext()

    static func normalized(image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        let output = NSImage(size: size)
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSImage(cgImage: cgImage, size: size)
            .draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        return output
    }

    static func croppedToRatio(image: NSImage, ratio: CGFloat) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil), ratio > 0 else {
            return nil
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let currentRatio = width / height

        let cropRect: CGRect
        if currentRatio > ratio {
            let cropWidth = height * ratio
            cropRect = CGRect(x: (width - cropWidth) / 2, y: 0, width: cropWidth, height: height)
        } else {
            let cropHeight = width / ratio
            cropRect = CGRect(x: 0, y: (height - cropHeight) / 2, width: width, height: cropHeight)
        }

        guard let cropped = cgImage.cropping(to: cropRect.integral) else {
            return nil
        }

        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    static func shouldApplyColorEffect(for filter: BoothFilter) -> Bool {
        false
    }

    static func render(image: NSImage, filter: BoothFilter) -> NSImage? {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let ciImage = CIImage(bitmapImageRep: bitmap) else {
            return image
        }

        let filtered = shouldApplyColorEffect(for: filter) ? render(ciImage: ciImage, filter: filter) : ciImage
        let composited = compositeOverlayIfNeeded(on: filtered, filter: filter)

        guard let cgImage = context.createCGImage(composited, from: composited.extent) else {
            return image
        }
        return NSImage(cgImage: cgImage, size: image.size)
    }

    private static func render(ciImage: CIImage, filter: BoothFilter) -> CIImage {
        switch filter {
        case .orangeLogo:
            return ciImage
        case .whiteLogo:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = ciImage
            return mono.outputImage ?? ciImage
        case .house:
            return adjusted(ciImage, saturation: 1.08, brightness: 0.03, contrast: 1.06, temperature: 7200)
        case .digiCam:
            return adjusted(ciImage, saturation: 0.98, brightness: 0.01, contrast: 1.04, temperature: 5200)
        }
    }

    private static func compositeOverlayIfNeeded(on image: CIImage, filter: BoothFilter) -> CIImage {
        guard let filename = filter.overlayFilename,
              let overlay = ResourceImage.loadFilter(named: filename),
              let tiff = overlay.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let overlayImage = CIImage(bitmapImageRep: bitmap) else {
            return image
        }

        let scaledOverlay = overlayImage
            .transformed(by: CGAffineTransform(
                scaleX: image.extent.width / overlayImage.extent.width,
                y: image.extent.height / overlayImage.extent.height
            ))
            .cropped(to: image.extent)

        let composite = CIFilter.sourceOverCompositing()
        composite.inputImage = scaledOverlay
        composite.backgroundImage = image
        return composite.outputImage ?? image
    }

    private static func adjusted(_ image: CIImage, saturation: Float, brightness: Float, contrast: Float, temperature: Float) -> CIImage {
        let color = CIFilter.colorControls()
        color.inputImage = image
        color.saturation = saturation
        color.brightness = brightness
        color.contrast = contrast

        let temp = CIFilter.temperatureAndTint()
        temp.inputImage = color.outputImage ?? image
        temp.neutral = CIVector(x: CGFloat(temperature), y: 0)
        temp.targetNeutral = CIVector(x: 6500, y: 0)
        return temp.outputImage ?? color.outputImage ?? image
    }
}
