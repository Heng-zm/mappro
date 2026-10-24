import SwiftUI

struct DirectionsSheet: View {
    @ObservedObject var engine: MapEngine
    let onClose: () -> Void

    @State private var detent: PresentationDetent = .height(390)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                modePicker
                Divider()
                content
            }
            .navigationTitle(engine.directionsDestination?.name ?? "Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .accessibilityLabel("Close directions")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if engine.selectedRoute != nil {
                        Button("Start") {
                            engine.startNavigation()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .presentationDetents([.height(390), .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var modePicker: some View {
        Picker(
            "Travel mode",
            selection: Binding(
                get: { engine.travelMode },
                set: { engine.setTravelMode($0) }
            )
        ) {
            ForEach(TravelMode.allCases) { mode in
                Label(mode.title, systemImage: mode.symbolName)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if engine.isRouting {
            VStack(spacing: 14) {
                ProgressView()
                Text("Finding the best route…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = engine.routeError, engine.routeOptions.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppTheme.orange)
                Text(engine.routeErrorTitle)
                    .font(.headline)
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button {
                    engine.requestDirections()
                } label: {
                    Text("Try again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppTheme.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if engine.routeOptions.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.turn.up.right.circle")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Choose a destination to get directions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            routeList
        }
    }

    private var routeList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 10) {
                    ForEach(engine.routeOptions) { option in
                        Button {
                            engine.selectRoute(option)
                        } label: {
                            routeCard(option)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let selectedRoute = engine.selectedRoute {
                    stepsSection(route: selectedRoute)

                    if let attribution = selectedRoute.source.attributionText {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Apple Maps couldn't calculate this route, so MapPro used OpenStreetMap.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                                Text(attribution)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.blue)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    engine.startNavigation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                        Text("Start navigation")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if engine.selectedRoute?.source == .appleMaps {
                    Button {
                        engine.openInAppleMaps()
                    } label: {
                        Label("Voice navigation in Apple Maps", systemImage: "arrow.up.forward.app")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                AppTheme.blue.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text(
                    engine.selectedRoute?.source == .openStreetMap
                        ? "In-app guidance shows maneuvers, remaining time, live speed in km/h, and spoken directions. Voice handoff isn't available for this route."
                        : "In-app guidance shows maneuvers, remaining time, live speed in km/h, and spoken directions."
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private func routeCard(_ option: RouteOption) -> some View {
        let selected = engine.selectedRouteID == option.id

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(option.timeText)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(option.distanceText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("\(option.viaText) · \(option.source.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Arrive at \(option.arrivalText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .padding(14)
        .background(
            selected ? AppTheme.blue.opacity(0.08) : Color.primary.opacity(0.045),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? AppTheme.blue : Color.clear, lineWidth: 1.4)
        )
    }

    private func stepsSection(route: RouteOption) -> some View {
        let steps = route.steps

        return VStack(alignment: .leading, spacing: 0) {
            Text("Steps")
                .font(.headline)
                .padding(.bottom, 6)

            if steps.isEmpty {
                Text("No step details available for this route.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(index == 0 ? AppTheme.green.opacity(0.15) : Color.primary.opacity(0.06))
                                .frame(width: 30, height: 30)
                            Image(systemName: ManeuverSymbol.symbol(for: step.instructions))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(index == 0 ? AppTheme.green : Color.secondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.instructions)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if step.distance > 0 {
                                Text(Formatters.distance(step.distance))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)

                    if index < steps.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
        }
        .padding(14)
        .background(
            Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
