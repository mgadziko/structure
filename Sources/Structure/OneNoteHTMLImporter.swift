import Foundation

struct OneNoteImportedBlock: Equatable {
    let pageName: String
    let notebook: String
    let section: String
    let blockType: String
    let blockOrder: Int
    let body: String
}

enum OneNoteHTMLImportError: LocalizedError, Equatable {
    case unsupportedNativeNotebook
    case noPagesFound
    case unreadablePage(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedNativeNotebook:
            return "Structure cannot read native .one or .onepkg files yet. Export the pages as HTML/XHTML from a Graph-based exporter, then choose the exported file or folder."
        case .noPagesFound:
            return "No HTML or XHTML pages were found in the selected location."
        case .unreadablePage(let url):
            return "Could not read the OneNote page at \(url.lastPathComponent)."
        }
    }
}

enum OneNoteHTMLImporter {
    static func load(from url: URL) throws -> [OneNoteImportedBlock] {
        let extensionName = url.pathExtension.lowercased()
        if extensionName == "one" || extensionName == "onepkg" {
            throw OneNoteHTMLImportError.unsupportedNativeNotebook
        }

        let pageURLs = try htmlPageURLs(at: url)
        guard !pageURLs.isEmpty else { throw OneNoteHTMLImportError.noPagesFound }

        let notebook = url.deletingPathExtension().lastPathComponent
        return try pageURLs.flatMap { pageURL in
            let data: Data
            do {
                data = try Data(contentsOf: pageURL)
            } catch {
                throw OneNoteHTMLImportError.unreadablePage(pageURL)
            }
            return OneNotePageHTMLParser.parse(
                data: data,
                fallbackPageName: pageURL.deletingPathExtension().lastPathComponent,
                notebook: notebook,
                section: sectionName(for: pageURL, under: url)
            )
        }
    }

    private static func htmlPageURLs(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw OneNoteHTMLImportError.noPagesFound
        }
        if !isDirectory.boolValue {
            return [url].filter(isHTMLPage)
        }
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        return (FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: options)?
            .compactMap { $0 as? URL }
            .filter(isHTMLPage) ?? [])
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private static func isHTMLPage(_ url: URL) -> Bool {
        ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased())
    }

    private static func sectionName(for pageURL: URL, under rootURL: URL) -> String {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return ""
        }
        let relativePath = pageURL.deletingLastPathComponent().path.replacingOccurrences(of: rootURL.path, with: "")
        return relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

final class OneNotePageHTMLParser: NSObject, XMLParserDelegate {
    private let fallbackPageName: String
    private let notebook: String
    private let section: String
    private var pageName: String
    private var blocks: [OneNoteImportedBlock] = []
    private var elementStack: [String] = []
    private var currentText = ""
    private var currentCells: [String] = []
    private var currentCellText = ""
    private var currentImageAlt = ""

    init(fallbackPageName: String, notebook: String, section: String) {
        self.fallbackPageName = fallbackPageName
        self.pageName = fallbackPageName
        self.notebook = notebook
        self.section = section
    }

    static func parse(data: Data, fallbackPageName: String, notebook: String, section: String) -> [OneNoteImportedBlock] {
        let delegate = OneNotePageHTMLParser(fallbackPageName: fallbackPageName, notebook: notebook, section: section)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            // Graph output is XHTML, but a browser-exported page can be imperfect HTML.
            // NSAttributedString still gives us a useful single-entry fallback in that case.
            let plainText = (try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
            ).string) ?? ""
            let body = normalized(plainText)
            return body.isEmpty ? [] : [OneNoteImportedBlock(
                pageName: fallbackPageName,
                notebook: notebook,
                section: section,
                blockType: "Page",
                blockOrder: 1,
                body: body
            )]
        }
        return delegate.blocks
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let element = elementName.lowercased()
        elementStack.append(element)
        if element == "tr" {
            currentCells = []
        } else if element == "td" || element == "th" {
            currentCellText = ""
        } else if element == "img", !isInTable {
            currentImageAlt = attributeDict["alt"] ?? ""
            appendBlock(type: "Image", body: currentImageAlt.isEmpty ? "[Image]" : "[Image: \(currentImageAlt)]")
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
        if elementStack.contains("td") || elementStack.contains("th") {
            currentCellText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = elementName.lowercased()
        defer { _ = elementStack.popLast() }

        if element == "title" {
            let title = normalized(currentText)
            if !title.isEmpty { pageName = title }
            currentText = ""
            return
        }

        if element == "td" || element == "th" {
            currentCells.append(normalized(currentCellText))
            currentCellText = ""
            return
        }

        if element == "tr", !currentCells.allSatisfy(\.isEmpty) {
            appendBlock(type: "Table Row", body: currentCells.joined(separator: " | "))
            return
        }

        guard !isInTable else { return }
        let blockType: String?
        switch element {
        case "p": blockType = "Paragraph"
        case "li": blockType = "List Item"
        case "h1", "h2", "h3", "h4", "h5", "h6": blockType = "Heading"
        case "pre": blockType = "Preformatted"
        default: blockType = nil
        }
        guard let blockType else { return }
        let text = normalized(currentText)
        currentText = ""
        guard !text.isEmpty else { return }
        appendBlock(type: blockType, body: blockType == "List Item" ? "- \(text)" : text)
    }

    private var isInTable: Bool {
        elementStack.contains("table")
    }

    private func appendBlock(type: String, body: String) {
        blocks.append(OneNoteImportedBlock(
            pageName: pageName,
            notebook: notebook,
            section: section,
            blockType: type,
            blockOrder: blocks.count + 1,
            body: body
        ))
    }
}

private func normalized(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\\u{00A0}", with: " ")
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}
