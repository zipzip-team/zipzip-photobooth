import AppKit

enum PrintRenderer {
    static let paperSizeMillimeters = CGSize(width: 100, height: 148)

    static func print(image: NSImage?, filter: BoothFilter, orientation: PrintOrientation = .landscape) {
        guard let image else { return }
        let filtered = ImageProcessor.render(image: image, filter: filter) ?? image
        let printImage = ImageProcessor.normalized(image: filtered) ?? filtered
        let view = PrintablePhotoView(image: printImage, orientation: orientation)

        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        let portrait = CGSize(width: paperSizeMillimeters.width * 72.0 / 25.4, height: paperSizeMillimeters.height * 72.0 / 25.4)
        printInfo.paperSize = orientation == .landscape ? CGSize(width: portrait.height, height: portrait.width) : portrait
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let operation = NSPrintOperation(view: view, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}

final class PrintablePhotoView: NSView {
    private let image: NSImage
    private let paperPoints: CGSize

    init(image: NSImage, orientation: PrintOrientation) {
        self.image = image
        let portrait = CGSize(width: 100 * 72.0 / 25.4, height: 148 * 72.0 / 25.4)
        self.paperPoints = orientation == .landscape ? CGSize(width: portrait.height, height: portrait.width) : portrait
        super.init(frame: CGRect(origin: .zero, size: paperPoints))
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = max(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let drawSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: (bounds.width - drawSize.width) / 2,
            y: (bounds.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
