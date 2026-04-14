import SwiftUI
import AppKit

struct MenuBarLabelView: View {
    let snapshot: StatusSnapshot

    var body: some View {
        if let labelText = snapshot.labelText {
            if snapshot.progressStyle == .pieChart,
               let progressPercent = snapshot.progressPercent {
                Image(
                    nsImage: StatusLabelImageFactory.makeTimeAndPieImage(
                        text: labelText,
                        progress: Double(progressPercent) / 100.0
                    )
                )
            } else {
                Text(labelText)
                    .monospacedDigit()
            }
        } else {
            Image(systemName: snapshot.labelSymbol)
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var model: CountdownModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.snapshot.menuTitle)
                .font(.headline)

            if let detail = model.snapshot.menuDetail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Preferences…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }

            Button("Quit") {
                model.quitApp()
            }
        }
        .padding(12)
        .frame(minWidth: 240, alignment: .leading)
    }
}

private enum StatusLabelImageFactory {
    static func makeTimeAndPieImage(text: String, progress: Double) -> NSImage {
        let textFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: NSColor.labelColor
        ]
        let textSize = NSAttributedString(string: text, attributes: textAttributes).size()
        let pieSize = NSSize(width: 12, height: 12)
        let spacing: CGFloat = 4
        let canvasSize = NSSize(
            width: ceil(textSize.width + spacing + pieSize.width),
            height: ceil(max(textSize.height, pieSize.height))
        )

        let image = NSImage(size: canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let textOrigin = NSPoint(
            x: 0,
            y: floor((canvasSize.height - textSize.height) / 2)
        )
        NSString(string: text).draw(at: textOrigin, withAttributes: textAttributes)

        let pieOrigin = NSPoint(
            x: ceil(textSize.width + spacing),
            y: floor((canvasSize.height - pieSize.height) / 2)
        )
        let pieRect = NSRect(origin: pieOrigin, size: pieSize)
        drawPie(progress: progress, in: pieRect)

        image.isTemplate = false
        return image
    }

    private static func drawPie(progress: Double, in rect: NSRect) {
        let size = NSSize(width: 12, height: 12)
        let clamped = min(max(progress, 0), 1)
        let circleRect = NSRect(origin: rect.origin, size: size).insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(ovalIn: circleRect)
        NSColor.labelColor.withAlphaComponent(0.14).setFill()
        background.fill()

        if clamped > 0 {
            let pie = NSBezierPath()
            pie.move(to: NSPoint(x: circleRect.midX, y: circleRect.midY))
            pie.appendArc(
                withCenter: NSPoint(x: circleRect.midX, y: circleRect.midY),
                radius: circleRect.width / 2,
                startAngle: 90,
                endAngle: 90 - (360 * clamped),
                clockwise: true
            )
            pie.close()
            NSColor.labelColor.setFill()
            pie.fill()
        }

        NSColor.labelColor.withAlphaComponent(0.2).setStroke()
        background.lineWidth = 0.5
        background.stroke()
    }
}
