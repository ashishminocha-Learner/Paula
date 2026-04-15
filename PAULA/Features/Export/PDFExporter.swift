import PDFKit
import SwiftUI
import UIKit

/// Generates a PDF document from a recording's transcript and summary.
struct PDFExporter {

    struct ExportContent {
        let title: String
        let date: Date
        let duration: String
        let transcript: [SpeakerTurn]
        let summary: String?
        let template: SummaryTemplate?
    }

    /// Returns PDF data for the given content.
    func export(content: ExportContent) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 points
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { ctx in
            ctx.beginPage()

            var yOffset: CGFloat = 40

            // Title
            yOffset = drawText(
                content.title,
                at: CGPoint(x: 40, y: yOffset),
                maxWidth: pageRect.width - 80,
                font: .boldSystemFont(ofSize: 22),
                color: .label,
                pageRect: pageRect,
                context: ctx
            )

            // Meta line
            let meta = "\(content.date.formatted(date: .long, time: .shortened))  •  \(content.duration)"
            yOffset = drawText(
                meta,
                at: CGPoint(x: 40, y: yOffset + 6),
                maxWidth: pageRect.width - 80,
                font: .systemFont(ofSize: 11),
                color: .secondaryLabel,
                pageRect: pageRect,
                context: ctx
            )

            yOffset += 20
            drawLine(at: yOffset, pageRect: pageRect)
            yOffset += 16

            // Summary section
            if let summary = content.summary, !summary.isEmpty {
                let label = content.template?.displayName ?? "Summary"
                yOffset = drawSectionHeader("Summary (\(label))",
                                            at: yOffset, pageRect: pageRect,
                                            context: ctx)
                yOffset = drawText(
                    summary,
                    at: CGPoint(x: 40, y: yOffset + 6),
                    maxWidth: pageRect.width - 80,
                    font: .systemFont(ofSize: 12),
                    color: .label,
                    pageRect: pageRect,
                    context: ctx
                )
                yOffset += 20
                drawLine(at: yOffset, pageRect: pageRect)
                yOffset += 16
            }

            // Transcript section
            yOffset = drawSectionHeader("Transcript", at: yOffset, pageRect: pageRect, context: ctx)
            yOffset += 8

            for turn in content.transcript {
                // Check if we need a new page
                if yOffset > pageRect.height - 80 {
                    ctx.beginPage()
                    yOffset = 40
                }

                // Speaker label
                yOffset = drawText(
                    "\(turn.speakerLabel)  [\(turn.formattedTime)]",
                    at: CGPoint(x: 40, y: yOffset),
                    maxWidth: pageRect.width - 80,
                    font: .boldSystemFont(ofSize: 11),
                    color: .secondaryLabel,
                    pageRect: pageRect,
                    context: ctx
                )

                // Turn text
                yOffset = drawText(
                    turn.text,
                    at: CGPoint(x: 40, y: yOffset + 2),
                    maxWidth: pageRect.width - 80,
                    font: .systemFont(ofSize: 12),
                    color: .label,
                    pageRect: pageRect,
                    context: ctx
                )
                yOffset += 12
            }
        }
    }

    // MARK: - Drawing helpers

    @discardableResult
    private func drawText(
        _ text: String,
        at point: CGPoint,
        maxWidth: CGFloat,
        font: UIFont,
        color: UIColor,
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let constraintRect = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: constraintRect,
                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                             attributes: attrs, context: nil)

        // New page if content would overflow bottom margin
        if point.y + boundingBox.height > pageRect.height - 40 {
            context.beginPage()
            let newPoint = CGPoint(x: point.x, y: 40)
            // Re-measure on new page (same width, so result is identical, but be explicit)
            text.draw(in: CGRect(x: newPoint.x, y: newPoint.y,
                                 width: maxWidth, height: boundingBox.height),
                      withAttributes: attrs)
            return newPoint.y + boundingBox.height + 2   // +2pt leading after text
        }

        text.draw(in: CGRect(origin: point, size: CGSize(width: maxWidth, height: boundingBox.height)),
                  withAttributes: attrs)
        return point.y + boundingBox.height
    }

    @discardableResult
    private func drawSectionHeader(
        _ text: String,
        at y: CGFloat,
        pageRect: CGRect,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        return drawText(text, at: CGPoint(x: 40, y: y),
                        maxWidth: pageRect.width - 80,
                        font: .boldSystemFont(ofSize: 14),
                        color: .label,
                        pageRect: pageRect,
                        context: context)
    }

    private func drawLine(at y: CGFloat, pageRect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 40, y: y))
        path.addLine(to: CGPoint(x: pageRect.width - 40, y: y))
        UIColor.separator.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
}
