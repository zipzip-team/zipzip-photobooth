import AppKit
import SwiftUI

enum PrintOrientation {
    case landscape
    case portrait

    var ratio: CGFloat {
        switch self {
        case .landscape:
            return 148.0 / 100.0
        case .portrait:
            return 100.0 / 148.0
        }
    }

}

struct ContentView: View {
    @EnvironmentObject private var camera: CameraModel
    @State private var selectedFilter: BoothFilter = .orangeLogo
    @State private var isShowingFilters = false

    private let filters: [BoothFilter] = [.orangeLogo, .whiteLogo, .house, .digiCam]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            PrintRatioFrame(orientation: .landscape) {
                ZStack {
                    if let image = camera.capturedImage {
                        FilteredImageView(image: image, filter: selectedFilter)
                            .id(selectedFilter.id)
                    } else {
                        CameraPreview(session: camera.session)
                            .scaleEffect(x: -1, y: 1)
                        FilterOverlayView(filter: selectedFilter)
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                bottomBar
            }

            if camera.authorizationState != .authorized {
                PermissionView(message: camera.authorizationState.message)
            }

            if isShowingFilters {
                FilterPickerOverlay(
                    filters: filters,
                    selectedFilter: $selectedFilter,
                    isShowing: $isShowingFilters
                )
            }
        }
        .background {
            KeyboardEventMonitor(onKeyDown: handleKeyDown)
                .allowsHitTesting(false)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard !event.isARepeat, NSApp.modalWindow == nil else { return false }

        switch event.keyCode {
        case 49: // Space
            guard camera.capturedImage == nil,
                  camera.authorizationState == .authorized,
                  !isShowingFilters else { return false }
            camera.capturePhoto(orientation: .landscape)
            return true

        case 15: // R
            guard camera.capturedImage != nil, !isShowingFilters else { return false }
            camera.capturedImage = nil
            return true

        case 53: // Escape
            guard isShowingFilters else { return false }
            isShowingFilters = false
            return true

        default:
            return false
        }
    }

    private var bottomBar: some View {
        ZStack {
            HStack {
                Button {
                    camera.capturedImage = nil
                } label: {
                    Text("다시")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 40)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(width: 72, height: 40)
                .contentShape(Capsule())
                .background(.white.opacity(camera.capturedImage == nil ? 0.08 : 0.16), in: Capsule())
                .disabled(camera.capturedImage == nil)

                Spacer()

                Button {
                    isShowingFilters = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.grid.2x2")
                        Text("필터")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 40)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .frame(width: 92, height: 40)
                .contentShape(Capsule())
                .background(.white.opacity(0.16), in: Capsule())
            }

            if camera.capturedImage == nil {
                Button {
                    camera.capturePhoto(orientation: .landscape)
                } label: {
                    CaptureIcon()
                        .frame(width: 74, height: 74)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(camera.authorizationState != .authorized)
            } else {
                HStack(spacing: 12) {
                    Button {
                        PrintRenderer.saveJPEG(image: camera.capturedImage, filter: selectedFilter)
                    } label: {
                        Text("Save")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 54)
                            .contentShape(Capsule())
                            .background(.black.opacity(0.34), in: Capsule())
                            .overlay {
                                Capsule().stroke(.white.opacity(0.75), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 96, height: 54)
                    .contentShape(Capsule())

                    Button {
                        PrintRenderer.print(image: camera.capturedImage, filter: selectedFilter, orientation: .landscape)
                    } label: {
                        Text("Print")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 96, height: 54)
                            .contentShape(Capsule())
                            .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 96, height: 54)
                    .contentShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
        .frame(height: 116)
        .background(
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct KeyboardEventMonitor: NSViewRepresentable {
    let onKeyDown: (NSEvent) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyDown: onKeyDown)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.start()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onKeyDown = onKeyDown
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        var onKeyDown: (NSEvent) -> Bool
        private var monitor: Any?

        init(onKeyDown: @escaping (NSEvent) -> Bool) {
            self.onKeyDown = onKeyDown
        }

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.onKeyDown(event) ? nil : event
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            stop()
        }
    }
}

struct CaptureIcon: View {
    var body: some View {
        if let image = ResourceImage.load(named: "new-camera-icon", ext: "svg") {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Circle().fill(.white)
                Circle().stroke(.black.opacity(0.18), lineWidth: 3).padding(5)
            }
        }
    }
}

struct PermissionView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 18, weight: .semibold))
            Text("System Settings에서 카메라 권한을 허용한 뒤 앱을 다시 실행하세요.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PrintRatioFrame<Content: View>: View {
    let orientation: PrintOrientation
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let size = orientation == .landscape
                ? coverSize(in: proxy.size, ratio: orientation.ratio)
                : fitSize(in: proxy.size, ratio: orientation.ratio)

            content
                .frame(width: size.width, height: size.height)
                .background(.black)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    private func coverSize(in bounds: CGSize, ratio: CGFloat) -> CGSize {
        let heightByWidth = bounds.width / ratio
        if heightByWidth >= bounds.height {
            return CGSize(width: bounds.width, height: heightByWidth)
        }
        return CGSize(width: bounds.height * ratio, height: bounds.height)
    }

    private func fitSize(in bounds: CGSize, ratio: CGFloat) -> CGSize {
        let heightByWidth = bounds.width / ratio
        if heightByWidth <= bounds.height {
            return CGSize(width: bounds.width, height: heightByWidth)
        }
        return CGSize(width: bounds.height * ratio, height: bounds.height)
    }
}

struct FilterPickerOverlay: View {
    let filters: [BoothFilter]
    @Binding var selectedFilter: BoothFilter
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            VStack(spacing: 18) {
                HStack {
                    Text("필터")
                        .font(.system(size: 20, weight: .semibold))
                    Spacer()
                    Button {
                        isShowing = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(filters) { filter in
                        Button {
                            selectedFilter = filter
                            isShowing = false
                        } label: {
                            FilterTile(filter: filter, isSelected: selectedFilter == filter)
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(22)
            .frame(width: 430)
            .background(.black.opacity(0.86), in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
        }
    }
}

struct FilterTile: View {
    let filter: BoothFilter
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(filter.previewFill)

                FilterOverlayView(filter: filter)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }
            .aspectRatio(1.48, contentMode: .fit)

            Text(filter.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(8)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .background(isSelected ? .white.opacity(0.18) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
