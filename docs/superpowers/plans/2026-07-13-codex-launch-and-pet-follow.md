# Codex Launch and Pet Follow Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start Codex Pet Usage when Codex updates its state and correct pet-overlay geometry with the live macOS Codex window frame.

**Architecture:** Keep JSON as the source of pet-relative geometry, then apply a pure origin-delta correction when a size-matching live `com.openai.codex` window is available. Register the installed app with a user LaunchAgent that watches the Codex global-state file, avoiding a permanent helper process.

**Tech Stack:** Swift 6, Foundation, AppKit, Core Graphics window metadata, SwiftPM custom tests, shell LaunchAgent verifier.

---

## File structure

- Modify `Sources/CodexPetUsageCore/CodexStateReader.swift`: retain the JSON overlay frame and expose pure live-origin correction.
- Create `Sources/CodexPetUsageCore/WindowFrameMatcher.swift`: choose the closest independently size-matching live frame.
- Modify `Tests/CodexPetUsageTests/CodexStateReaderTests.swift`: reproduce the confirmed 30-point stale-origin bug and fallback behavior.
- Create `Tests/CodexPetUsageTests/WindowFrameMatcherTests.swift`: cover candidate matching and deterministic selection.
- Modify `Tests/CodexPetUsageTests/main.swift`: register the new tests.
- Create `Sources/CodexPetUsageApp/CodexWindowLocator.swift`: read live frames owned by `com.openai.codex` without window contents.
- Modify `Sources/CodexPetUsageApp/AppCoordinator.swift`: apply live correction on each existing pet poll.
- Modify `InstallStartup.command`: prefer the installed app, write `WatchPaths`, bootstrap immediately, and start when Codex is already active.
- Modify `Tests/Shell/verify-control-commands.sh`: isolate and verify installed/local selection, WatchPaths, bootstrap, and Codex-active start.
- Modify `README.md` and `docs/verification.md`: document startup semantics and final evidence.

### Task 1: Add pure window matching and geometry correction

**Files:**
- Create: `Sources/CodexPetUsageCore/WindowFrameMatcher.swift`
- Create: `Tests/CodexPetUsageTests/WindowFrameMatcherTests.swift`
- Modify: `Sources/CodexPetUsageCore/CodexStateReader.swift`
- Modify: `Tests/CodexPetUsageTests/CodexStateReaderTests.swift`
- Modify: `Tests/CodexPetUsageTests/main.swift`

- [ ] **Step 1: Write failing matcher tests**

Add tests proving:

```swift
closestMatchingWindowFrame(
    expected: CGRect(x: 1498, y: 0, width: 356, height: 320),
    candidates: [
        CGRect(x: 0, y: 30, width: 1866, height: 1050),
        CGRect(x: 1498, y: 30, width: 356, height: 320),
    ]
) == CGRect(x: 1498, y: 30, width: 356, height: 320)
```

Also cover independent one-point width/height tolerance, rejection beyond the
tolerance, negative origins, closest-origin selection, equal-distance input
order, and an empty candidate list.

- [ ] **Step 2: Run focused matcher test and verify RED**

Run: `swift run CodexPetUsageTests selectsLivePetWindowBySizeAndDistance`

Expected: compilation fails because `closestMatchingWindowFrame` is absent.

- [ ] **Step 3: Implement the minimal pure matcher**

Create:

```swift
import CoreGraphics

public func closestMatchingWindowFrame(
    expected: CGRect,
    candidates: [CGRect],
    sizeTolerance: CGFloat = 1
) -> CGRect? {
    var best: (frame: CGRect, distance: CGFloat)?
    for frame in candidates {
        guard abs(frame.width - expected.width) <= sizeTolerance,
              abs(frame.height - expected.height) <= sizeTolerance else { continue }
        let dx = frame.minX - expected.minX
        let dy = frame.minY - expected.minY
        let distance = dx * dx + dy * dy
        if best == nil || distance < best!.distance {
            best = (frame, distance)
        }
    }
    return best?.frame
}
```

Use strict `<` replacement so equal-distance candidates preserve input order.

- [ ] **Step 4: Run matcher tests and verify GREEN**

Run: `swift run CodexPetUsageTests windowFrame`

Expected: all matcher tests pass.

- [ ] **Step 5: Write failing geometry correction tests**

Extend the existing open-pet fixture assertions to retain the JSON overlay
frame. Add a test using JSON origin `(1498, 0)`, mascot-relative origin
`(248, 87)`, and live frame `(1498, 30, 356, 320)`. Assert corrected values:

```swift
corrected.topLeftRect == CGRect(x: 1746, y: 117, width: 80, height: 87)
corrected.appKitRect == CGRect(x: 1746, y: 876, width: 80, height: 87)
```

Assert that a nil live frame returns unchanged geometry and that the resulting
overlay layout frame shifts by `(0, -30)` in AppKit coordinates. Add a second
case with a nonzero horizontal origin delta and assert the pet/layout x values
move by that exact amount. JSON overlay bounds and Core Graphics window bounds
are both treated as global top-left coordinates; conversion to AppKit happens
only after applying their top-left origin delta.

- [ ] **Step 6: Run correction test and verify RED**

Run: `swift run CodexPetUsageTests liveOverlayOriginCorrectsStaleJSONGeometry`

Expected: compilation fails because the overlay frame and correction method are absent.

- [ ] **Step 7: Retain and correct overlay geometry**

Add `overlayTopLeftRect: CGRect?` to `PetGeometry`, defaulting to nil in its
initializer so existing synthetic callers remain unchanged. `CodexStateReader`
sets it only when JSON width and height exist. Add:

```swift
public func corrected(liveOverlayFrame: CGRect?, primaryMaxY: CGFloat) -> PetGeometry {
    guard let jsonFrame = overlayTopLeftRect, let liveOverlayFrame else { return self }
    let correctedTopLeft = topLeftRect.offsetBy(
        dx: liveOverlayFrame.minX - jsonFrame.minX,
        dy: liveOverlayFrame.minY - jsonFrame.minY
    )
    return PetGeometry(
        topLeftRect: correctedTopLeft,
        appKitRect: CGRect(
            x: correctedTopLeft.minX,
            y: primaryMaxY - correctedTopLeft.minY - correctedTopLeft.height,
            width: correctedTopLeft.width,
            height: correctedTopLeft.height
        ),
        displayTopLeftRect: displayTopLeftRect,
        overlayTopLeftRect: liveOverlayFrame
    )
}
```

- [ ] **Step 8: Run core tests and verify GREEN**

Run:

```bash
swift run CodexPetUsageTests liveOverlayOriginCorrectsStaleJSONGeometry
swift run CodexPetUsageTests openPetProducesGlobalTopLeftAndAppKitRects
swift run CodexPetUsageTests layout
```

Expected: all selected tests pass.

- [ ] **Step 9: Commit the pure correction**

```bash
git add Sources/CodexPetUsageCore Tests/CodexPetUsageTests
git commit -m "fix: correct pet geometry with live window frames"
```

### Task 2: Read the live Codex pet window on every existing poll

**Files:**
- Create: `Sources/CodexPetUsageApp/CodexWindowLocator.swift`
- Modify: `Sources/CodexPetUsageApp/AppCoordinator.swift`

- [ ] **Step 1: Implement the thin macOS metadata adapter**

Create an app-target type that:

1. collects process IDs from `NSWorkspace.shared.runningApplications` whose
   `bundleIdentifier == "com.openai.codex"`;
2. calls `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)`;
3. keeps only entries whose `kCGWindowOwnerPID` belongs to that set;
4. converts `kCGWindowBounds` dictionaries to `CGRect` values;
5. delegates final selection to `closestMatchingWindowFrame`.

Return nil for every missing/invalid state without logging at poll frequency.

- [ ] **Step 2: Integrate correction into `updateOverlay`**

After reading JSON geometry, compute:

```swift
let pet = statePet.map { geometry in
    let liveFrame = geometry.overlayTopLeftRect.flatMap {
        CodexWindowLocator.liveOverlayFrame(expected: $0)
    }
    return geometry.corrected(liveOverlayFrame: liveFrame, primaryMaxY: primaryMaxY)
}
```

Keep hover-state and layout code unchanged below this boundary.

- [ ] **Step 3: Build the app target**

Run: `swift build --product CodexPetUsage`

Expected: the AppKit/Core Graphics adapter compiles without warnings or new permissions.

- [ ] **Step 4: Commit live window integration**

```bash
git add Sources/CodexPetUsageApp
git commit -m "fix: follow the live Codex pet window"
```

### Task 3: Register best-effort Codex-triggered startup

**Files:**
- Modify: `Tests/Shell/verify-control-commands.sh`
- Modify: `InstallStartup.command`
- Modify: `README.md`

- [ ] **Step 1: Write failing isolated startup assertions**

Extend the fake command directory with `lsappinfo` and `launchctl` recorders. The fake
inactive `lsappinfo` must exit zero with empty output, matching the real macOS
command. Set
`CODEX_PET_INSTALLED_APP` to a nonexistent temporary path for the local fallback
case. Assert after repeated installation:

- `WatchPaths.0` equals `$CODEX_HOME/.codex-global-state.json`;
- `RunAtLoad`, `KeepAlive`, and polling helpers are absent;
- `launchctl bootstrap gui/<uid> <plist>` is called;
- with Codex reported inactive, neither `open` nor `kickstart` is called;
- with a temporary installed bundle executable present and Codex reported active,
  `ProgramArguments.0` selects that executable and launchd kickstarts the exact
  service label after exact-process termination;
- an exact selected process and a late-arriving exact process are terminated,
  while a same-basename executable at another path remains running;
- process discovery failure aborts before kickstart;
- switching path sources and repeated installs still produce one plist and exact
  bootout/bootstrap/kickstart operations.

- [ ] **Step 2: Run shell verifier and verify RED**

Run: `bash Tests/Shell/verify-control-commands.sh`

Expected: FAIL because current installation writes `RunAtLoad`, omits WatchPaths
and bootstrap, and always targets the repository bundle.

- [ ] **Step 3: Implement startup selection and registration**

In `InstallStartup.command`:

- define `INSTALLED_APP="${CODEX_PET_INSTALLED_APP:-/Applications/Codex Pet Usage.app}"`;
- use its executable when valid, otherwise build/use `dist/Codex Pet Usage.app`;
- write a one-element `WatchPaths` array containing the state file;
- omit `RunAtLoad` and `KeepAlive`;
- atomically replace the plist;
- `bootout` the exact plist tolerantly, then `bootstrap` it;
- repeatedly resolve and terminate only the exact selected executable, rescanning
  for late arrivals and failing closed if process discovery fails;
- capture `lsappinfo find bundleID=com.openai.codex` output tolerantly and, only
  when nonempty, `launchctl kickstart` the exact service label after handoff;
- when Codex is inactive, leave the job waiting for its `WatchPaths` trigger.

Do not add a polling loop, broad process matching, or privileged command.

#### Runtime amendment: launchd-owned handoff

The initial active-Codex implementation used `open -g`, which could race the
newly bootstrapped LaunchAgent and briefly create two exact executable
processes. The reviewed implementation does not call `open`. It terminates only
the exact selected executable, rescans for a late arrival, fails closed on
discovery errors, and then hands active-Codex startup to launchd with an exact
label `kickstart`. Inactive-Codex installation stops any pre-existing exact
process and waits for `WatchPaths`.

- [ ] **Step 4: Run shell verifier and verify GREEN**

Run: `bash Tests/Shell/verify-control-commands.sh`

Expected: PASS with installed/local path selection and all existing lifecycle isolation checks.

- [ ] **Step 5: Update README startup description**

Document immediate LaunchAgent registration, state-file-triggered best-effort
startup, installed-app preference, and the absence of an always-running helper.

- [ ] **Step 6: Commit startup behavior**

```bash
git add InstallStartup.command Tests/Shell/verify-control-commands.sh README.md
git commit -m "feat: start usage overlay when Codex state changes"
```

### Task 4: Full verification, installation, and real-device evidence

**Files:**
- Modify: `docs/verification.md`

- [ ] **Step 1: Run all automated verification**

Run:

```bash
swift run CodexPetUsageTests
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Pet Usage.app"
file "dist/Codex Pet Usage.app/Contents/MacOS/CodexPetUsage"
plutil -lint "dist/Codex Pet Usage.app/Contents/Info.plist"
git diff --check
```

Expected: all tests pass, control verifier passes, signature/plist are valid,
and the executable remains arm64 Mach-O.

- [ ] **Step 2: Record the exact test count and behavior**

Update `docs/verification.md` with the new count, live frame correction evidence,
and WatchPaths startup evidence. Commit the record.

- [ ] **Step 3: Install the verified bundle**

Terminate only the exact installed usage executable, copy the new bundle to
`/Applications/Codex Pet Usage.app`, and verify it. Do not launch it manually;
the following installer step owns the launch handoff.

- [ ] **Step 4: Register startup on this Mac**

Run the verified `InstallStartup.command`. Confirm the installed plist points to
`/Applications`, watches the current Codex state file, is loaded in the user
launchd domain, and does not contain `RunAtLoad` or `KeepAlive`.

- [ ] **Step 5: Verify real coordinate correction**

Compare the current JSON overlay frame, the current live Core Graphics frame,
and the corrected mascot position. Confirm a 30-point live-origin difference
moves the computed overlay by 30 points and that no permission prompt appears.

- [ ] **Step 6: Finish the development branch**

Use `superpowers:finishing-a-development-branch`, present integration options,
and execute the user's selection only after fresh verification.
