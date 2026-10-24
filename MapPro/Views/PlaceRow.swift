import SwiftUI

struct PlaceRow: View {
    let place: Place
    let distance: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(place.tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: place.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(place.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let distance {
                Text(distance)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}
