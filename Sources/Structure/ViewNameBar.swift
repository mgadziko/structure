import SwiftUI

struct ViewControlsBar: View {
    let title: String
    let activeViewID: StructureView.ID?
    let views: [StructureView]
    let hasOpenLibrary: Bool
    let openView: (StructureView.ID) -> Void
    let createView: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Menu {
                ForEach(otherViews) { view in
                    Button(view.title) {
                        openView(view.id)
                    }
                }
                if !otherViews.isEmpty {
                    Divider()
                }
                Button("New ...") {
                    createView()
                }
                .disabled(!hasOpenLibrary)
            } label: {
                HStack(spacing: 6) {
                    Text(title.isEmpty ? "No View Open" : title)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(minWidth: 180, alignment: .leading)
            }
            .menuStyle(.button)
            .disabled(!hasOpenLibrary)

            Spacer()
        }
        .padding(.horizontal, EntryRowLayout.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var otherViews: [StructureView] {
        views
            .filter { $0.id != activeViewID }
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }
}
