import SwiftUI

struct ViewNameBar: View {
    let title: String
    let rename: (String) -> Void
    let beginEditing: () -> Void
    @State private var isEditing = false
    @State private var draftTitle = ""
    @FocusState private var titleIsFocused: Bool

    var body: some View {
        HStack {
            if isEditing {
                TextField("View Name", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
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
                Text(title.isEmpty ? "No View Open" : title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(title.isEmpty ? .secondary : .primary)
                    .onTapGesture(count: 2) {
                        guard !title.isEmpty else { return }
                        beginEditing()
                        draftTitle = title
                        isEditing = true
                    }
            }

            Spacer()
        }
        .padding(.horizontal, EntryRowLayout.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color(nsColor: .textBackgroundColor))
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
