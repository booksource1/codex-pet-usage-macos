# Usage Window Classification Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correctly map live usage buckets to five-hour and seven-day semantics by declared duration and render missing windows as `--` rather than `0%`.

**Architecture:** Normalize raw `primary_window` and `secondary_window` buckets at the `UsageDecoder` boundary so the existing snapshot's `primary*` fields remain five-hour semantics and `secondary*` fields remain seven-day semantics. Keep missing-value display and operational log formatting as pure functions in `OverlayPresentation.swift`, then have `AppCoordinator` consume the tested log formatter.

**Tech Stack:** Swift 6, Foundation, AppKit, the existing custom SwiftPM test runner, shell bundle verifier.

---

## File structure

- Modify `Sources/CodexPetUsageCore/UsageDecoder.swift`: classify raw buckets by `limit_window_seconds`/`window_seconds` before decoding semantic snapshot fields.
- Modify `Tests/CodexPetUsageTests/UsageDecoderTests.swift`: reproduce the current live response and cover legacy/mixed bucket behavior.
- Modify `Sources/CodexPetUsageCore/OverlayPresentation.swift`: format each missing window as `--` and provide one tested operational log-line formatter.
- Modify `Tests/CodexPetUsageTests/OverlayPresentationTests.swift`: cover missing percentage, missing reset, ring percentage, and log output.
- Modify `Sources/CodexPetUsageApp/AppCoordinator.swift`: use the tested operational log formatter.
- Modify `docs/verification.md`: update the verified test count after the final run.

### Task 1: Classify buckets by declared window duration

**Files:**
- Modify: `Tests/CodexPetUsageTests/UsageDecoderTests.swift`
- Modify: `Sources/CodexPetUsageCore/UsageDecoder.swift`

- [ ] **Step 1: Write failing decoder tests**

Add test cases equivalent to:

```swift
TestCase(name: "sevenDayBucketInPrimarySlotUsesDeclaredDuration") {
    let data = jsonData(#"{"rate_limit":{"primary_window":{"used_percent":23,"limit_window_seconds":604800}}}"#)
    let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
    try expect(usage?.primaryRemaining == nil, "missing five-hour window must remain missing")
    try expectApproximately(usage?.secondaryRemaining, 77, "604800-second bucket must be seven-day usage")
    try expect(usage?.primaryWindowSeconds == nil, "missing five-hour duration must remain missing")
    try expectApproximately(usage?.secondaryWindowSeconds, 604_800, "seven-day duration must follow the bucket")
},
TestCase(name: "durationlessBucketsRetainLegacyPositions") {
    let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":61},"secondary_window":{"remaining_percent":42}}}"#)
    let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
    try expectApproximately(usage?.primaryRemaining, 61, "durationless primary remains five-hour")
    try expectApproximately(usage?.secondaryRemaining, 42, "durationless secondary remains seven-day")
},
TestCase(name: "declaredDurationDisablesPositionalInference") {
    let data = jsonData(#"{"rate_limit":{"primary_window":{"remaining_percent":77,"limit_window_seconds":604800},"secondary_window":{"remaining_percent":55,"limit_window_seconds":3600}}}"#)
    let usage = try UsageDecoder.decode(data: data, source: .test, now: fixedDate())
    try expect(usage?.primaryRemaining == nil, "unrecognized bucket must not be inferred as five-hour")
    try expectApproximately(usage?.secondaryRemaining, 77, "recognized seven-day bucket must survive")
},
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift run CodexPetUsageTests sevenDayBucketInPrimarySlotUsesDeclaredDuration
```

Expected: FAIL because the current decoder assigns the primary slot to five-hour semantics.

- [ ] **Step 3: Add minimal duration-based classification**

In `UsageDecoder.decode`, read the two raw buckets and normalize them before calculating values:

```swift
let rawPrimary = firstDictionary(rate["primary_window"], rate["primary"])
let rawSecondary = firstDictionary(rate["secondary_window"], rate["secondary"])
let (primary, secondary) = classifiedBuckets(primary: rawPrimary, secondary: rawSecondary)
```

Add a private helper:

```swift
private static func classifiedBuckets(
    primary: [String: Any]?,
    secondary: [String: Any]?
) -> (fiveHour: [String: Any]?, sevenDay: [String: Any]?) {
    let buckets = [primary, secondary].compactMap { $0 }
    guard buckets.contains(where: { windowSeconds(in: $0) != nil }) else {
        return (primary, secondary)
    }

    var fiveHour: [String: Any]?
    var sevenDay: [String: Any]?
    for bucket in buckets {
        switch windowSeconds(in: bucket) {
        case 18_000 where fiveHour == nil:
            fiveHour = bucket
        case 604_800 where sevenDay == nil:
            sevenDay = bucket
        default:
            break
        }
    }
    return (fiveHour, sevenDay)
}
```

- [ ] **Step 4: Run focused decoder tests and verify GREEN**

Run:

```bash
swift run CodexPetUsageTests sevenDayBucketInPrimarySlotUsesDeclaredDuration
swift run CodexPetUsageTests durationlessBucketsRetainLegacyPositions
swift run CodexPetUsageTests declaredDurationDisablesPositionalInference
```

Expected: all three pass.

- [ ] **Step 5: Commit decoder classification**

```bash
git add Sources/CodexPetUsageCore/UsageDecoder.swift Tests/CodexPetUsageTests/UsageDecoderTests.swift
git commit -m "fix: classify usage windows by duration"
```

### Task 2: Render and log missing windows as `--`

**Files:**
- Modify: `Tests/CodexPetUsageTests/OverlayPresentationTests.swift`
- Modify: `Sources/CodexPetUsageCore/OverlayPresentation.swift`
- Modify: `Sources/CodexPetUsageApp/AppCoordinator.swift`

- [ ] **Step 1: Write failing presentation and log tests**

Create a snapshot with five-hour fields absent and seven-day remaining `77`, with no seven-day reset. Assert:

```swift
try expect(model.primary == "5小时 剩余 -- · --后刷新", "missing five-hour window should use dashes")
try expect(model.secondary == "7天 剩余 77% · --后刷新", "present seven-day value should retain its percentage")
try expect(model.primaryPercent == 0, "missing five-hour value should draw no arc")
try expect(model.secondaryPercent == 77, "present seven-day value should draw its arc")
try expect(
    usageLogLine(snapshot) == "Usage updated: source=test, 5h=--, 7d=77",
    "missing windows must not be logged as zero"
)
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
swift run CodexPetUsageTests missingWindowUsesDashes
```

Expected: FAIL because the current presentation converts missing percentages to zero and `usageLogLine` does not exist.

- [ ] **Step 3: Add minimal per-window formatting**

In `OverlayPresentation.swift`, format percentage text independently from ring percentages:

```swift
let primaryText = snapshot.primaryRemaining.map { "\(integer(clamped($0)))%" } ?? "--"
let secondaryText = snapshot.secondaryRemaining.map { "\(integer(clamped($0)))%" } ?? "--"
```

Use those strings in the two lines while keeping missing ring values at zero. Add:

```swift
public func usageLogLine(_ snapshot: UsageSnapshot) -> String {
    let primary = snapshot.primaryRemaining.map { String(Int($0.rounded())) } ?? "--"
    let secondary = snapshot.secondaryRemaining.map { String(Int($0.rounded())) } ?? "--"
    return "Usage updated: source=\(snapshot.source.rawValue), 5h=\(primary), 7d=\(secondary)"
}
```

Replace the inline `String(format:)` block in `AppCoordinator` with `log(usageLogLine(snapshot))`.

- [ ] **Step 4: Run focused presentation tests and verify GREEN**

Run:

```bash
swift run CodexPetUsageTests missingWindowUsesDashes
swift run CodexPetUsageTests availablePresentationMatchesReferenceStrings
swift run CodexPetUsageTests unavailablePresentationMatchesReferenceStrings
```

Expected: all pass.

- [ ] **Step 5: Commit missing-window presentation**

```bash
git add Sources/CodexPetUsageCore/OverlayPresentation.swift Sources/CodexPetUsageApp/AppCoordinator.swift Tests/CodexPetUsageTests/OverlayPresentationTests.swift
git commit -m "fix: show missing usage windows as dashes"
```

### Task 3: Full verification, packaging, and local installation

**Files:**
- Modify: `docs/verification.md`

- [ ] **Step 1: Run the full Swift test suite**

Run: `swift run CodexPetUsageTests`

Expected: all existing and new tests pass with zero failures. Record the exact count in `docs/verification.md`.

- [ ] **Step 2: Run command and bundle verification**

Run:

```bash
bash Tests/Shell/verify-control-commands.sh
bash scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Codex Pet Usage.app"
file "dist/Codex Pet Usage.app/Contents/MacOS/CodexPetUsage"
plutil -lint "dist/Codex Pet Usage.app/Contents/Info.plist"
git diff --check
```

Expected: shell verifier passes, build succeeds, signature is valid, executable is arm64 Mach-O, plist is valid, and diff check is clean.

- [ ] **Step 3: Commit verification evidence**

```bash
git add docs/verification.md
git commit -m "docs: record window classification verification"
```

- [ ] **Step 4: Update and launch the installed app**

Terminate only the exact installed executable, copy `dist/Codex Pet Usage.app` over `/Applications/Codex Pet Usage.app`, verify its signature and plist, launch it, and confirm exactly one process exists. Do not install or enable the LaunchAgent.

- [ ] **Step 5: Verify the real API symptom**

Allow one refresh, then verify the operational log reports `5h=--, 7d=<value>` for the current 604800-second primary bucket. Do not print or persist the access token or complete API response.

- [ ] **Step 6: Finish the development branch**

Use `superpowers:finishing-a-development-branch` to merge or preserve the verified branch according to the user's selected integration workflow.
