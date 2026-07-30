import WidgetKit
import SwiftUI

/// A Watch complication providing one-tap access to the most frequently used Location Preset.
struct LCGComplicationEntry: TimelineEntry {
    let date: Date
    let presetName: String?
}

struct LCGComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> LCGComplicationEntry {
        LCGComplicationEntry(date: .now, presetName: "LCG")
    }

    func getSnapshot(in context: Context, completion: @escaping (LCGComplicationEntry) -> Void) {
        let topPreset = WatchSessionManager.shared.presets.first
        let entry = LCGComplicationEntry(date: .now, presetName: topPreset?.name ?? "LCG")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LCGComplicationEntry>) -> Void) {
        let topPreset = WatchSessionManager.shared.presets.first
        let entry = LCGComplicationEntry(date: .now, presetName: topPreset?.name ?? "LCG")
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30)))
        completion(timeline)
    }
}

struct LCGComplicationView: View {
    let entry: LCGComplicationEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 2) {
                Image(systemName: "elevator.fill")
                    .font(.caption)
                if let name = entry.presetName {
                    Text(name)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .widgetURL(complicationURL(for: entry.presetName))
    }

    private func complicationURL(for presetName: String?) -> URL? {
        guard let name = presetName else { return nil }
        return URL(string: "lcgremote://activate?preset=\(name)")
    }
}

/// Widget definition for the LCG complication.
/// Add this to a Widget Extension target for deployment.
struct LCGComplicationWidget: Widget {
    let kind: String = "LCGComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LCGComplicationProvider()) { entry in
            LCGComplicationView(entry: entry)
        }
        .configurationDisplayName("LCG Remote")
        .description("Quick access to your most-used elevator preset.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
