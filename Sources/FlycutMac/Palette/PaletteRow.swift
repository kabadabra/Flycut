import SwiftUI
import FlycutCore

struct PaletteRow: View {
    let clip: Clip
    let selected: Bool
    let showSource: Bool
    let showType: Bool
    let previewLength: Int
    let onClick: (Int) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(clip.text.prefix(previewLength))).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if showSource {
                    Text(clip.sourceAppName ?? "Unknown source")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay { ImmediateRowClickSurface(onClick: onClick) }
            if showType {
                SelectableTypeLabel(text: "Type: \(clip.pasteboardType)", onClick: onClick)
                    .padding(.horizontal, 8).padding(.bottom, 5)
            }
        }
        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
