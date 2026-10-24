import SwiftUI

struct MapControlsView: View {
    @ObservedObject var engine: MapEngine

    var body: some View {
        VStack(spacing: 10) {
            Button(action: engine.recenterOnUser) {
                MapControlCircle(
                    symbol: "location.fill",
                    active: engine.isLocationAuthorized
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("My location")

            Button {
                engine.dropPin(at: engine.mapRegion.center)
            } label: {
                MapControlCircle(symbol: "mappin.and.ellipse")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Drop a pin at map center")

            Button(action: engine.resetNorth) {
                MapControlCircle(
                    symbol: "location.north.fill",
                    active: false,
                    rotation: .degrees(-engine.heading)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset north")

            Menu {
                ForEach(MapLayer.allCases) { layer in
                    Button {
                        engine.setLayer(layer)
                    } label: {
                        Label(
                            layer.title,
                            systemImage: engine.mapLayer == layer ? "checkmark.circle.fill" : layer.symbolName
                        )
                    }
                }

                Divider()

                Button {
                    engine.toggleTraffic()
                } label: {
                    Label(
                        engine.trafficEnabled ? "Hide traffic" : "Show traffic",
                        systemImage: "car.fill"
                    )
                }
            } label: {
                MapControlCircle(
                    symbol: "square.3.layers.3d",
                    active: engine.mapLayer != .standard || engine.trafficEnabled
                )
            }
            .accessibilityLabel("Map layers")

            Button(action: engine.toggle3D) {
                Text(engine.is3D ? "2D" : "3D")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(engine.is3D ? Color.white : Color.primary)
                    .frame(width: 42, height: 42)
                    .background(engine.is3D ? AppTheme.blue : Color.clear, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.is3D ? "Switch to 2D" : "Switch to 3D")
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 0.6))
        .shadow(color: Color.black.opacity(0.2), radius: 14, y: 5)
    }
}

struct MapControlCircle: View {
    let symbol: String
    var active: Bool = false
    var rotation: Angle = .zero

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .rotationEffect(rotation)
            .foregroundStyle(active ? Color.white : Color.primary)
            .frame(width: 42, height: 42)
            .background(active ? AppTheme.blue : Color.clear, in: Circle())
            .contentShape(Circle())
    }
}
