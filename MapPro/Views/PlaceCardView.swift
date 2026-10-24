import SwiftUI

struct PlaceCardView: View {
    let place: Place
    let distance: String?
    let isSaved: Bool
    let onClose: () -> Void
    let onDirections: () -> Void
    let onToggleSave: () -> Void
    let onCopyCoordinates: () -> Void
    let onLookAround: () -> Void
    var onRemovePin: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            coordinateButton
            actionChips
            bottomActions
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 22, y: 8)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(place.tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: place.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(place.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(place.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(place.categoryName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(place.tint)
                    if let distance {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(distance)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 2)

            VStack(spacing: 6) {
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSaved ? AppTheme.blue : Color.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            (isSaved ? AppTheme.blue.opacity(0.14) : Color.primary.opacity(0.07)),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Remove from saved places" : "Save place")

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close place details")
            }
        }
    }

    private var coordinateButton: some View {
        Button(action: onCopyCoordinates) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)

                VStack(alignment: .leading, spacing: 1) {
                    Text("COORDINATES")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(place.coordinateText)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 6)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy coordinates")
    }

    private var actionChips: some View {
        HStack(spacing: 8) {
            if let phoneURL = place.phoneURL {
                Link(destination: phoneURL) {
                    actionChip(title: "Call", symbol: "phone.fill", tint: AppTheme.blue)
                }
            }
            if let websiteURL = place.websiteURL {
                Link(destination: websiteURL) {
                    actionChip(title: "Website", symbol: "globe", tint: AppTheme.blue)
                }
            }

            Button(action: onLookAround) {
                actionChip(title: "Look Around", symbol: "binoculars.fill", tint: AppTheme.teal)
            }
            .buttonStyle(.plain)

            if let onRemovePin {
                Button(action: onRemovePin) {
                    actionChip(title: "Remove pin", symbol: "trash", tint: AppTheme.red)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }

    private var bottomActions: some View {
        HStack(spacing: 10) {
            Button(action: onDirections) {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.blue, in: Capsule())
            }
            .buttonStyle(.plain)

            ShareLink(item: place.shareURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 44, height: 44)
                    .background(AppTheme.blue.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Share place")
        }
    }

    private func actionChip(title: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(tint.opacity(0.1), in: Capsule())
    }
}
