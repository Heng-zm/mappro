import SwiftUI

struct CategoryChipsView: View {
    let onSelect: (ExploreCategory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreCategory.all) { category in
                    Button {
                        onSelect(category)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(category.color)
                            Text(category.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 1)
        }
    }
}
