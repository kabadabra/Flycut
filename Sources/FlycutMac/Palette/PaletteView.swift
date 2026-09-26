import SwiftUI
import FlycutCore

struct PaletteView: View {
    @ObservedObject var model: PaletteModel
    @FocusState private var searching: Bool
    @State private var confirmClear = false
    @State private var showHelp = false
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Flycut Evolution").font(.title2.bold())
                Spacer()
                Button(action: model.pause) { Image(systemName: model.isPaused ? "play.fill" : "pause.fill") }
                    .help(model.isPaused ? "Resume capture" : "Pause capture")
                    .accessibilityLabel(model.isPaused ? "Resume capture" : "Pause capture")
                Menu {
                    Button("Merge All Recents", action: model.merge)
                    Button("Export Collection…") { model.perform(.exportAll) }
                    Button("Clear All Recents…") { confirmClear = true }
                    Divider()
                    Button("Keyboard Help") { showHelp.toggle() }
                    Button("Settings…", action: model.settings)
                    Button("About Flycut Evolution", action: model.about)
                    Divider()
                    Button("Quit Flycut Evolution", action: model.quit)
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Flycut commands")
            }
            TextField("Search clippings", text: $model.selection.query)
                .textFieldStyle(.roundedBorder).focused($searching).accessibilityLabel("Search clippings")
            Picker("Collection", selection: $model.selection.collection) {
                Text("Recents").tag(CollectionKind.recent)
                Text("Favorites").tag(CollectionKind.favorite)
            }.pickerStyle(.segmented)
            if let warning = model.storageWarning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            if let message = model.message { Text(message).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
            if model.needsAccessibility { Button("Open Accessibility Settings", action: model.accessibility) }
            if model.isPaused { Label("Capture paused", systemImage: "pause.circle").font(.caption) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 3) {
                        if model.selection.clips.isEmpty {
                            Text(model.selection.query.isEmpty ? "No clippings yet" : "No matching clippings")
                                .foregroundStyle(.secondary).padding(30)
                        }
                        ForEach(model.visibleClips, id: \.id) { clip in
                            PaletteRow(clip: clip, selected: clip.id == model.selection.selectedID,
                                       showSource: model.showSource, showType: model.showTypes, previewLength: model.previewLength)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { model.selection.select(clip.id); model.activateSelection() }
                            .accessibilityAction(named: "Activate Clipping") { model.selection.select(clip.id); model.activateSelection() }
                            .onTapGesture { searching = false; model.selection.select(clip.id) }
                            .contextMenu {
                                Button("Move to Favorites") { model.selection.select(clip.id); model.perform(.favorite) }
                                    .disabled(clip.collection == .favorite)
                                Button("Export…") { model.selection.select(clip.id); model.perform(.exportSelected) }
                                Button("Delete") { model.selection.select(clip.id); model.perform(.delete) }
                            }.id(clip.id)
                        }
                    }
                }.onChange(of: model.selection.selectedID) { id in if let id { proxy.scrollTo(id) } }
                .onChange(of: model.presentation) { _ in if let id = model.selection.selectedID { proxy.scrollTo(id) } }
                .onAppear { if let id = model.selection.selectedID { proxy.scrollTo(id) } }
            }
            if model.visibleClips.count < model.selection.clips.count {
                Button("Show All \(model.selection.clips.count) Clippings") { model.showAll = true }
            }
            HStack {
                Button("Favorite") { model.perform(.favorite) }.disabled(model.selection.collection == .favorite || model.selection.selected == nil)
                Button("Save…") { model.perform(.exportSelected) }.disabled(model.selection.selected == nil)
                Spacer()
                Button { showHelp.toggle() } label: { Image(systemName: "questionmark.circle") }.accessibilityLabel("Keyboard help")
            }
            if showHelp {
                Text("↑/↓ or j/k · Home/End · Page Up/Down · 1–0 select\nDouble-click or Return to copy and paste when a text field is focused · Esc close\nDelete remove · f favorite · F switch list · s save selected · S save collection\nTab leave search · ⌘F search · Letters and digits edit text while searching.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.padding(16).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Rectangle().fill(.regularMaterial)
                .overlay(Color(nsColor: .windowBackgroundColor).opacity(model.backgroundOpacity))
        }
        .onExitCommand { model.perform(.dismiss) }
        .onAppear { searching = true }
        .onChange(of: model.presentation) { _ in searching = true }
        .alert("Allow automatic paste?", isPresented: $model.showAccessibilityAlert) {
            Button("Open Accessibility Settings", action: model.accessibility)
            Button("Keep Using Copy", role: .cancel) {}
        } message: { Text("Your clipping was copied. Allow Flycut in Accessibility settings to paste into the previous app. You can suppress this reminder in Privacy settings.") }
        .alert("Clear all recent clippings?", isPresented: $confirmClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Recents", role: .destructive, action: model.clear)
        } message: { Text("Favorites will be kept. This cannot be undone.") }
    }
}
