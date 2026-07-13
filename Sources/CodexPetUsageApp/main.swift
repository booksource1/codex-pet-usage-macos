import AppKit
import CodexPetUsageCore

let application = NSApplication.shared
let coordinator = AppCoordinator(configuration: RuntimeConfiguration())
application.setActivationPolicy(.accessory)
application.delegate = coordinator
application.run()
