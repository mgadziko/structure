import SwiftUI

struct EntryColumnHeader: View {
    var body: some View {
        HStack {
            Text("Entry")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 38)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
