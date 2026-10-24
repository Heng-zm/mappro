import SwiftUI
import CoreLocation

struct SavedPlacesPanel: View {
    @ObservedObject var store: FavoritesStore
    let userCoordinate: CLLocationCoordinate2D?
    let onSelect: (SavedPlace) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .background(.regularMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saved places")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(store.isEmpty ? "Your pins and favorites" : "\(store.count) \(store.count == 1 ? "place" : "places")")
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
            .accessibilityLabel("Close saved places")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(AppTheme.blue.opacity(0.12))
                    .frame(width: 62, height: 62)
                Image(systemName: "bookmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
            }

            Text("No saved places yet")
                .font(.headline)

            Text("Tap the bookmark on a place card, or long-press anywhere on the map to save a coordinate pin.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 20)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.places) { saved in
                    HStack(spacing: 4) {
                        Button {
                            onSelect(saved)
                        } label: {
                            PlaceRow(
                                place: saved.place,
                                distance: saved.place.distanceText(from: userCoordinate)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.remove(saved)
                            }
                            Haptics.tap()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(saved.name)")
                    }
                    .padding(.horizontal, 18)

                    Divider().padding(.leading, 68)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }
}
