import AppKit
import SwiftUI
import FlycutCore

@MainActor final class PaletteModel: ObservableObject {
    @Published var selection = PaletteSelection()
    @Published var isPaused = false
    @Published var message: String?
    @Published var needsAccessibility = false
    @Published var showSource = true
    @Published var previewLength = 40
    @Published var presentation = UUID()
    var perform: (PaletteCommand) -> Void = { _ in }
    var copy: () -> Void = {}
    var pause: () -> Void = {}
    var clear: () -> Void = {}
    var merge: () -> Void = {}
    var settings: () -> Void = {}
    var about: () -> Void = {}
    var accessibility: () -> Void = {}
    var quit: () -> Void = {}
}
