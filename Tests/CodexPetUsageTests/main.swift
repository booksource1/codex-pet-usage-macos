import Darwin
import Foundation

let allTests = packageSmokeTests + usageDecoderTests
let filter = CommandLine.arguments.dropFirst().first
let selectedTests = allTests.filter { test in
    filter.map { test.name.localizedCaseInsensitiveContains($0) } ?? true
}

guard !selectedTests.isEmpty else {
    fputs("No tests matched\n", stderr)
    exit(2)
}

var failures = 0
for test in selectedTests {
    do {
        try test.body()
        print("PASS \(test.name)")
    } catch {
        failures += 1
        fputs("FAIL \(test.name): \(error)\n", stderr)
    }
}

print("Executed \(selectedTests.count) test(s), \(failures) failure(s)")
exit(failures == 0 ? 0 : 1)
