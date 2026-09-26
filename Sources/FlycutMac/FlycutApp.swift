import AppKit

@main
enum FlycutApp {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
