import Foundation
import ZIPFoundation

/// Generates a .docx file (Office Open XML) from a recording's transcript and summary.
/// DOCX is a ZIP archive containing XML files — no external library needed beyond ZIPFoundation.
///
/// NOTE: Add ZIPFoundation via Swift Package Manager:
///   https://github.com/weichsel/ZIPFoundation  (tag 0.9.19+)
struct DOCXExporter {

    struct ExportContent {
        let title: String
        let date: Date
        let duration: String
        let transcript: [SpeakerTurn]
        let summary: String?
        let template: SummaryTemplate?
    }

    /// Returns DOCX file data.
    func export(content: ExportContent) throws -> Data {
        // Build the required DOCX XML files
        let documentXML = buildDocumentXML(content: content)
        let relsXML = buildRelsXML()
        let contentTypesXML = buildContentTypesXML()
        let appXML = buildAppXML()
        let coreXML = buildCoreXML(title: content.title, date: content.date)

        // Create in-memory archive
        let archiveData = NSMutableData()
        let archive: Archive
        do {
            archive = try Archive(data: archiveData as Data, accessMode: .create)
        } catch {
            throw DOCXError.archiveCreationFailed
        }

        func addEntry(_ path: String, _ xml: String) throws {
            guard let data = xml.data(using: .utf8) else { return }
            try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { _, _ in
                return data
            }
        }

        try addEntry("[Content_Types].xml", contentTypesXML)
        try addEntry("_rels/.rels", relsXML)
        try addEntry("word/document.xml", documentXML)
        try addEntry("docProps/app.xml", appXML)
        try addEntry("docProps/core.xml", coreXML)

        // ZIPFoundation writes to the NSMutableData via its custom accessor
        return archiveData as Data
    }

    // MARK: - XML builders

    private func buildDocumentXML(content: ExportContent) -> String {
        var body = ""

        // Title paragraph
        body += wParagraph(text: content.title, style: "Heading1", bold: true, size: 32)

        // Meta info
        let meta = "\(content.date.formatted(date: .long, time: .shortened))  •  \(content.duration)"
        body += wParagraph(text: meta, color: "666666", size: 18)

        body += wParagraph(text: "")  // spacer

        // Summary
        if let summary = content.summary, !summary.isEmpty {
            let label = content.template?.displayName ?? "Summary"
            body += wParagraph(text: "Summary (\(label))", style: "Heading2", bold: true, size: 24)
            // Split markdown-ish lines
            for line in summary.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("## ") {
                    body += wParagraph(text: String(trimmed.dropFirst(3)), bold: true, size: 22)
                } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") {
                    body += wParagraph(text: "  " + String(trimmed.dropFirst(2)), size: 20)
                } else if !trimmed.isEmpty {
                    body += wParagraph(text: trimmed, size: 20)
                }
            }
            body += wParagraph(text: "")
        }

        // Transcript
        body += wParagraph(text: "Transcript", style: "Heading2", bold: true, size: 24)
        body += wParagraph(text: "")

        for turn in content.transcript {
            body += wParagraph(text: "\(turn.speakerLabel)  [\(turn.formattedTime)]",
                               bold: true, color: "444444", size: 18)
            body += wParagraph(text: turn.text, size: 20)
            body += wParagraph(text: "")
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
                    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <w:body>
        \(body)
            <w:sectPr>
              <w:pgSz w:w="12240" w:h="15840"/>
              <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
            </w:sectPr>
          </w:body>
        </w:document>
        """
    }

    private func wParagraph(
        text: String,
        style: String? = nil,
        bold: Bool = false,
        color: String? = nil,
        size: Int = 20
    ) -> String {
        var pPr = ""
        if let style {
            pPr = "<w:pPr><w:pStyle w:val=\"\(style)\"/></w:pPr>"
        }

        var rPr = "<w:rPr>"
        if bold { rPr += "<w:b/>" }
        if let color { rPr += "<w:color w:val=\"\(color)\"/>" }
        rPr += "<w:sz w:val=\"\(size)\"/>"
        rPr += "</w:rPr>"

        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        return "<w:p>\(pPr)<w:r>\(rPr)<w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>\n"
    }

    private func buildRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
        </Relationships>
        """
    }

    private func buildContentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
        </Types>
        """
    }

    private func buildAppXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">
          <Application>PAULA</Application>
        </Properties>
        """
    }

    private func buildCoreXML(title: String, date: Date) -> String {
        let iso = ISO8601DateFormatter().string(from: date)
        let escaped = title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
                           xmlns:dc="http://purl.org/dc/elements/1.1/"
                           xmlns:dcterms="http://purl.org/dc/terms/"
                           xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>\(escaped)</dc:title>
          <dcterms:created xsi:type="dcterms:W3CDTF">\(iso)</dcterms:created>
        </cp:coreProperties>
        """
    }
}

enum DOCXError: LocalizedError {
    case archiveCreationFailed

    var errorDescription: String? { "Failed to create DOCX archive." }
}
