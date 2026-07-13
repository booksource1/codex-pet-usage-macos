import AppKit
import CodexPetUsageCore

@MainActor
final class AppCoordinator: NSObject, NSApplicationDelegate {
    private let configuration: RuntimeConfiguration
    private let usageService: UsageService

    private var logger: AppLogger?
    private var panel: OverlayPanel?
    private var usageTimer: Timer?
    private var petTimer: Timer?
    private var usageTask: Task<Void, Never>?
    private var refreshGate = RefreshGate()
    private var hoverState = HoverState()
    private var usageSnapshot = UsageSnapshot.unavailable(now: Date())

    init(configuration: RuntimeConfiguration) {
        self.configuration = configuration
        usageService = UsageService(codexHome: configuration.codexHome)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if anotherExactInstanceIsRunning() {
            NSApplication.shared.terminate(nil)
            return
        }

        do {
            logger = try AppLogger()
        } catch {
            NSApplication.shared.terminate(nil)
            return
        }

        let primaryMaxY = primaryScreenMaxY()
        let placeholderPet = PetGeometry(
            topLeftRect: CGRect(x: 0, y: 0, width: 80, height: 80),
            appKitRect: CGRect(x: 0, y: 0, width: 80, height: 80),
            displayTopLeftRect: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let layout = OverlayLayout.compute(pet: placeholderPet, primaryMaxY: primaryMaxY)
        panel = OverlayPanel(
            presentation: .make(snapshot: usageSnapshot),
            layout: layout
        )
        panel?.orderOut(nil)

        log("Overlay run started.")
        refreshUsage()
        updateOverlay()
        startTimers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageTimer?.invalidate()
        petTimer?.invalidate()
        usageTask?.cancel()
        log("Overlay run stopped.")
        logger?.removeOwnedPID()
    }

    private func startTimers() {
        let usageTimer = Timer(
            timeInterval: configuration.usagePollSeconds,
            target: self,
            selector: #selector(refreshUsage),
            userInfo: nil,
            repeats: true
        )
        let petTimer = Timer(
            timeInterval: Double(configuration.petPollMilliseconds) / 1_000,
            target: self,
            selector: #selector(updateOverlay),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(usageTimer, forMode: .common)
        RunLoop.main.add(petTimer, forMode: .common)
        self.usageTimer = usageTimer
        self.petTimer = petTimer
    }

    @objc private func refreshUsage() {
        guard refreshGate.begin() else { return }
        let service = usageService
        usageTask = Task { [weak self] in
            guard let self else { return }
            defer {
                refreshGate.end()
                usageTask = nil
            }
            let snapshot = await service.refresh()
            guard !Task.isCancelled else { return }
            usageSnapshot = snapshot
            if snapshot.available {
                log(String(
                    format: "Usage updated: source=%@, 5h=%.0f, 7d=%.0f",
                    snapshot.source.rawValue,
                    snapshot.primaryRemaining ?? 0,
                    snapshot.secondaryRemaining ?? 0
                ))
            } else {
                log("Usage unavailable.")
            }
            if hoverState.overlayWasVisible {
                updateOverlay()
            }
        }
    }

    @objc private func updateOverlay() {
        let now = Date()
        let primaryMaxY = primaryScreenMaxY()
        let pet = CodexStateReader.read(
            codexHome: configuration.codexHome,
            primaryMaxY: primaryMaxY
        )
        let wasVisible = hoverState.overlayWasVisible
        let cursorWasInPet = hoverState.cursorWasInPet
        let isVisible = hoverState.update(
            pet: pet,
            cursor: NSEvent.mouseLocation,
            now: now,
            padding: configuration.hoverPadding
        )

        guard isVisible, let pet else {
            if pet != nil, wasVisible {
                log("Hover display expired; overlay hidden.")
            }
            panel?.orderOut(nil)
            return
        }

        let layout = OverlayLayout.compute(pet: pet, primaryMaxY: primaryMaxY)
        panel?.update(
            presentation: .make(snapshot: usageSnapshot, now: now),
            layout: layout
        )
        panel?.orderFrontRegardless()

        if hoverState.cursorWasInPet, !cursorWasInPet {
            log(String(
                format: "Hover trigger: pet=(%.0f,%.0f,%.0f,%.0f), padding=%.0f",
                pet.topLeftRect.minX,
                pet.topLeftRect.minY,
                pet.topLeftRect.width,
                pet.topLeftRect.height,
                configuration.hoverPadding
            ))
        }
    }

    private func primaryScreenMaxY() -> CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    private func anotherExactInstanceIsRunning() -> Bool {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            return false
        }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.contains { application in
            application.processIdentifier != currentPID
                && application.executableURL?.resolvingSymlinksInPath() == executable
        }
    }

    private func log(_ candidate: String) {
        guard let message = LogMessagePolicy.validate(candidate) else { return }
        logger?.write(message)
    }
}
