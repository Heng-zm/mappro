import SwiftUI

struct PlaceCardView: View {
    let place: Place
    let distance: String?
    let onClose: () -> Void
    let onDirections: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

                Spacer(minLength: 4)

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

            if place.phoneURL != nil || place.websiteURL != nil {
                HStack(spacing: 8) {
                    if let phoneURL = place.phoneURL {
                        Link(destination: phoneURL) {
                            actionChip(title: "Call", symbol: "phone.fill")
                        }
                    }
                    if let websiteURL = place.websiteURL {
                        Link(destination: websiteURL) {
                            actionChip(title: "Website", symbol: "globe")
                        }
                    }
                }
            }

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
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCorner, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 22, y: 8)
    }

    private func actionChip(title: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppTheme.blue)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(AppTheme.blue.opacity(0.1), in: Capsule())
    }
}
