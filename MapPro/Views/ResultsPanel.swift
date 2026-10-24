import SwiftUI

struct ResultsPanel: View {
    @ObservedObject var engine: MapEngine
    let onSelect: (Place) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.lastQuery.isEmpty ? "Results" : engine.lastQuery)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close results")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            Divider()
            content
        }
        .frame(height: 352)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 20, y: 8)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var statusText: String {
        if engine.isSearching { return "Searching…" }
        if engine.places.isEmpty { return "No matches" }
        return "\(engine.places.count) \(engine.places.count == 1 ? "place" : "places")"
    }

    @ViewBuilder
    private var content: some View {
        if engine.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                Text("Finding places…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if engine.places.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("No places found")
                    .font(.headline)
                Text("Try another search or move the map.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(engine.places) { place in
                        Button {
                            onSelect(place)
                        } label: {
                            PlaceRow(
                                place: place,
                                distance: place.distanceText(from: engine.userCoordinate)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)

                        Divider().padding(.leading, 68)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }
}
