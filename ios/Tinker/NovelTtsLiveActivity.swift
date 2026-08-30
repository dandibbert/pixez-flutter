import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct NovelTtsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var displayText: String
        var page: Int
        var chunkIndex: Int
        var chunkTotal: Int
        var playbackState: String
    }

    var title: String
    var author: String
}

@available(iOSApplicationExtension 16.1, *)
struct NovelTtsLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NovelTtsActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 5) {
                Text(context.attributes.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.attributes.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(context.state.displayText)
                    .font(.body)
                    .lineLimit(3)
                HStack {
                    Text("Page \(context.state.page)")
                    Spacer()
                    Text("\(context.state.chunkIndex)/\(context.state.chunkTotal)")
                    Text(context.state.playbackState)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .activityBackgroundTint(Color.black.opacity(0.88))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("\(context.state.chunkIndex)/\(context.state.chunkTotal)")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.playbackState)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.displayText).lineLimit(2)
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                Text("\(context.state.chunkIndex)")
            } minimal: {
                Image(systemName: "waveform")
            }
        }
    }
}
