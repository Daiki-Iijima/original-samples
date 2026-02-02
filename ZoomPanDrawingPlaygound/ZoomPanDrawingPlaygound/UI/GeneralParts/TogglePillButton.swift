import SwiftUI

struct TogglePillButton: View {
    let title: String
    @Binding var isOn: Bool
    var systemImage: String? = nil

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .fontWeight(.semibold)

                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .imageScale(.medium)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isOn ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain) // 見た目を自前で作る
    }
}

#Preview {
    TogglePillButton(title: "Hello, World!", isOn: .constant(false))
}
