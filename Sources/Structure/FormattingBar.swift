import AppKit
import SwiftUI

struct FormattingBar: View {
    @State private var selectedSize = "17"
    @State private var selectedFamily = NSFont.systemFont(ofSize: 17).familyName ?? "System"

    private let fontSizes = ["8", "10", "12", "14", "16", "18", "20", "24", "28", "32", "36"]
    private let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
        $0.localizedStandardCompare($1) == .orderedAscending
    }

    var body: some View {
        HStack(spacing: 8) {
            FontSizeComboBox(values: fontSizes, text: $selectedSize) { value in
                guard let size = Double(value), size > 0 else { return }
                EntryFormattingCommands.applyFontSize(CGFloat(size))
            }
            .frame(width: 64, height: 24)

            Picker("Typeface", selection: $selectedFamily) {
                ForEach(fontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
            .frame(width: 180)
            .onChange(of: selectedFamily) { family in
                EntryFormattingCommands.applyFontFamily(family)
            }

            Divider()
                .frame(height: 22)

            FormatButton(title: "B", accessibilityLabel: "Bold", action: EntryFormattingCommands.toggleBold)
                .font(.system(size: 13, weight: .bold))
            FormatButton(title: "I", accessibilityLabel: "Italic", action: EntryFormattingCommands.toggleItalic)
                .italic()
            FormatButton(title: "U", accessibilityLabel: "Underline", action: EntryFormattingCommands.toggleUnderline)
                .underline()
            FormatButton(title: "S", accessibilityLabel: "Strikethrough", action: EntryFormattingCommands.toggleStrikethrough)
                .strikethrough()

            Divider()
                .frame(height: 22)

            FormatButton(title: "\u{2022}", accessibilityLabel: "Bullet List") {
                EntryFormattingCommands.toggleList(.bullet)
            }
            FormatButton(title: "1.", accessibilityLabel: "Numbered List") {
                EntryFormattingCommands.toggleList(.numbered)
            }

            Spacer()
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct FormatButton: View {
    let title: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct FontSizeComboBox: NSViewRepresentable {
    let values: [String]
    @Binding var text: String
    let onCommit: (String) -> Void

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.addItems(withObjectValues: values)
        comboBox.stringValue = text
        comboBox.completes = true
        comboBox.numberOfVisibleItems = values.count
        comboBox.delegate = context.coordinator
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        @Binding var text: String
        let onCommit: (String) -> Void

        init(text: Binding<String>, onCommit: @escaping (String) -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            commit(notification)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            commit(notification)
        }

        private func commit(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            text = comboBox.stringValue
            onCommit(comboBox.stringValue)
        }
    }
}
