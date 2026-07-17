import AppKit
import SwiftUI

enum PrintOrientation {
    case landscape
    case portrait

    mutating func toggle() {
        self = self == .landscape ? .portrait : .landscape
    }

    var ratio: CGFloat {
        switch self {
        case .landscape:
            return 148.0 / 100.0
        case .portrait:
            return 100.0 / 148.0
        }
    }

    var iconName: String {
        switch self {
        case .landscape:
            return "rotate.right"
        case .portrait:
            return "rotate.left"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var camera: CameraModel
    @State private var selectedFilter: BoothFilter = .orangeLogo
    @State private var orientation: PrintOrientation = .landscape
    @State private var isShowingFilters = false

    private let filters: [BoothFilter] = [.orangeLogo, .whiteLogo, .house, .digiCam]

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            PrintRatioFrame(orientation: orientation) {
                ZStack {
                    if let image = camera.capturedImage {
                        FilteredImageView(image: image, filter: selectedFilter)
                    } else {
                        CameraPreview(session: camera.session)
                        FilterOverlayView(filter: selectedFilter)
                    }
                }
            }
            .ignoresSafeArea()

            VStack {
                topBar
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
    }

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                orientation.toggle()
            } label: {
                Image(systemName: orientation.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 46, height: 38)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
            .help("방향 전환")
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .frame(height: 64)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.48), .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
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
                }
                .buttonStyle(.plain)
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
                }
                .buttonStyle(.plain)
                .background(.white.opacity(0.16), in: Capsule())
            }

            Button {
                if camera.capturedImage == nil {
                    camera.capturePhoto(orientation: orientation)
                } else {
                    PrintRenderer.print(image: camera.capturedImage, filter: selectedFilter, orientation: orientation)
                }
            } label: {
                if camera.capturedImage == nil {
                    CaptureIcon()
                        .frame(width: 74, height: 74)
                } else {
                    Text("Print")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 96, height: 54)
                        .background(.white, in: Capsule())
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .disabled(camera.authorizationState != .authorized)
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

struct CaptureIcon: View {
    var body: some View {
        if let image = ResourceImage.load(named: "사진찍기 아이콘", ext: "png") {
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
        .background(isSelected ? .white.opacity(0.18) : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
