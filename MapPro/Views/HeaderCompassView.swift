import SwiftUI

/// Compact compass shown in the map header. Tap to reset north.
struct HeaderCompassView: View {
    @ObservedObject var engine: MapEngine

    var body: some View {
        Button(action: engine.resetNorth) {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 0.6))
                    .shadow(color: Color.black.opacity(0.18), radius: 16, y: 6)

                VStack(spacing: 0) {
                    Text("N")
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(AppTheme.red)
                        .offset(y: 1)

                    Image(systemName: "location.north.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)
                        .rotationEffect(.degrees(-engine.heading))
                        .animation(.easeOut(duration: 0.18), value: engine.heading)
                }
                .padding(.top, 2)
            }
            .frame(width: 52, height: 52)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Compass")
        .accessibilityValue("\(Int(engine.heading.rounded())) degrees")
        .accessibilityHint("Double tap to reset north")
    }
}
