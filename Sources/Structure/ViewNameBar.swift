import SwiftUI

struct ViewControlsBar: View {
    let title: String
    let activeViewID: StructureView.ID?
    let views: [StructureView]
    let hasOpenLibrary: Bool
    let openView: (StructureView.ID) -> Void
    let createView: () -> Void
    let rename: (String) -> Void
    let beginEditing: () -> Void
    @State private var isEditing = false
    @State private var draftTitle = ""
    @FocusState private var titleIsFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            if isEditing {
                TextField("View Name", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 220, alignment: .leading)
                    .focused($titleIsFocused)
                    .onSubmit {
                        commit()
                    }
                    .onAppear {
                        draftTitle = title
                        DispatchQueue.main.async {
                            titleIsFocused = true
                        }
                    }
                    .onChange(of: titleIsFocused) { focused in
                        if !focused {
                            commit()
                        }
                    }
            } else {
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

                Button {
                    guard !title.isEmpty else { return }
                    beginEditing()
                    draftTitle = title
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(title.isEmpty ? .secondary : .primary)
                .disabled(title.isEmpty)
                .help("Rename View")
                .accessibilityLabel("Rename View")
            }

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

    private func commit() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            rename(trimmed)
        } else {
            draftTitle = title
        }
        isEditing = false
    }
}
