import SwiftUI

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        Text(toast.text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(toast.isError ? Color(hex: "#ff8060") : Color(hex: "#00d4ff"))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                toast.isError
                    ? Color(hex: "#ff3c1e").opacity(0.1)
                    : Color(hex: "#00d4ff").opacity(0.1)
            )
            .overlay(
                Capsule()
                    .stroke(
                        toast.isError
                            ? Color(hex: "#ff5032").opacity(0.3)
                            : Color(hex: "#00d4ff").opacity(0.3),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
            .shadow(
                color: toast.isError
                    ? Color(hex: "#ff3c1e").opacity(0.15)
                    : Color(hex: "#00d4ff").opacity(0.15),
                radius: 12
            )
    }
}
