import SwiftUI
import FlycutCore

struct PaletteRow: View {
    let clip: Clip
    let selected: Bool
    let showSource: Bool
    let previewLength: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(clip.text.prefix(previewLength))).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if showSource {
                HStack {
                    Text(clip.sourceAppName ?? "Unknown source")
                    Spacer()
                    if let date = clip.capturedAt { Text(date, style: .relative) }
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
