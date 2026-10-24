import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @FocusState.Binding var focus: Bool
    let isLoading: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(focus ? AppTheme.blue : Color.secondary)

            TextField("Search here", text: $text)
                .font(.system(size: 16, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus)
                .submitLabel(.search)
                .onSubmit(onSubmit)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.75)
            } else if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }

            if focus {
                Divider()
                    .frame(height: 22)

                Button("Cancel", action: onCancel)
                    .font(.system(size: 15, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.blue)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, y: 6)
        .animation(.easeInOut(duration: 0.2), value: focus)
    }
}
