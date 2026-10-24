import SwiftUI
import MapKit

/// Full-screen Apple Look Around preview for a coordinate.
struct LookAroundSheet: View {
    let place: Place

    @Environment(\.dismiss) private var dismiss
    @State private var scene: MKLookAroundScene?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasRequested = false
    @State private var request: MKLookAroundSceneRequest?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            content
            overlay
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private var content: some View {
        if let scene {
            LookAroundViewControllerView(scene: scene)
                .ignoresSafeArea()
        } else if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                Text("Loading Look Around…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        } else {
            unavailableState
        }
    }

    private var unavailableState: some View {
        VStack(spacing: 12) {
            Image(systemName: "binoculars.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text("Look Around isn't available here")
                .font(.headline)
                .foregroundStyle(.white)

            Text(errorMessage ?? "Apple hasn't published an immersive street-level scene for this coordinate yet.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Link(destination: place.shareURL) {
                Text("Open in Maps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
            .padding(.top, 4)
        }
    }

    private var overlay: some View {
        VStack {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(place.address)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(.black.opacity(0.42), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Look Around")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 26)
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.62), .black.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()
        }
        .ignoresSafeArea(edges: .top)
    }

    private func load() {
        guard !hasRequested else { return }
        hasRequested = true

        let request = MKLookAroundSceneRequest(coordinate: place.coordinate)
        self.request = request

        request.getSceneWithCompletionHandler { scene, error in
            DispatchQueue.main.async {
                isLoading = false
                if let scene {
                    self.scene = scene
                } else {
                    errorMessage = error?.localizedDescription
                }
            }
        }
    }
}

private struct LookAroundViewControllerView: UIViewControllerRepresentable {
    let scene: MKLookAroundScene

    func makeUIViewController(context: Context) -> MKLookAroundViewController {
        let controller = MKLookAroundViewController(scene: scene)
        controller.showsRoadLabels = true
        return controller
    }

    func updateUIViewController(_ uiViewController: MKLookAroundViewController, context: Context) {}
}
