import Foundation
import CodexPetUsageCore

let runtimeConfigurationTests: [TestCase] = [
    TestCase(name: "runtimeDefaultsMatchReference") {
        let home = URL(fileURLWithPath: "/tmp/codex-pet-home", isDirectory: true)
        let configuration = RuntimeConfiguration(environment: [:], homeDirectory: home)
        try expect(configuration.codexHome.path == "/tmp/codex-pet-home/.codex", "CODEX_HOME should default below the user home")
        try expect(configuration.usagePollSeconds == 30, "usage polling should default to 30 seconds")
        try expect(configuration.petPollMilliseconds == 100, "pet polling should default to 100 milliseconds")
        try expect(configuration.hoverPadding == 24, "hover padding should default to 24 points")
    },
    TestCase(name: "runtimeEnvironmentUsesExactNamesAndClampsMinimums") {
        let configuration = RuntimeConfiguration(
            environment: [
                "CODEX_HOME": "/tmp/fixture-codex",
                "CODEX_PET_USAGE_POLL_SECONDS": "4",
                "CODEX_PET_POLL_MS": "20",
                "CODEX_PET_HOVER_PADDING": "250",
            ],
            homeDirectory: URL(fileURLWithPath: "/tmp/ignored", isDirectory: true)
        )
        try expect(configuration.codexHome.path == "/tmp/fixture-codex", "explicit CODEX_HOME should be used")
        try expect(configuration.usagePollSeconds == 10, "usage polling should clamp to ten seconds")
        try expect(configuration.petPollMilliseconds == 50, "pet polling should clamp to fifty milliseconds")
        try expect(configuration.hoverPadding == 200, "hover padding should clamp to two hundred")
    },
    TestCase(name: "runtimeEnvironmentAcceptsValidValuesAndClampsNegativePadding") {
        var environment = [
            "CODEX_PET_USAGE_POLL_SECONDS": "45",
            "CODEX_PET_POLL_MS": "250",
            "CODEX_PET_HOVER_PADDING": "42",
        ]
        var configuration = RuntimeConfiguration(environment: environment, homeDirectory: URL(fileURLWithPath: "/tmp"))
        try expect(configuration.usagePollSeconds == 45, "valid usage interval should remain unchanged")
        try expect(configuration.petPollMilliseconds == 250, "valid pet interval should remain unchanged")
        try expect(configuration.hoverPadding == 42, "valid padding should remain unchanged")

        environment["CODEX_PET_HOVER_PADDING"] = "-1"
        configuration = RuntimeConfiguration(environment: environment, homeDirectory: URL(fileURLWithPath: "/tmp"))
        try expect(configuration.hoverPadding == 0, "negative padding should clamp to zero")
    },
    TestCase(name: "logPolicyAcceptsOperationalMessages") {
        let message = LogMessagePolicy.validate("Usage updated: source=log, 5h=63, 7d=48")
        try expect(message?.text == "Usage updated: source=log, 5h=63, 7d=48", "safe operational message should pass")
    },
    TestCase(name: "logPolicyRejectsCredentialsAndResponseContent") {
        let unsafeMessages = [
            "Authorization: Bearer secret",
            "access_token=secret",
            "token secret",
            "response body: {\"rate_limit\":{}}",
            "feedback_log_body={}",
        ]
        for message in unsafeMessages {
            try expect(LogMessagePolicy.validate(message) == nil, "unsafe log content should be rejected")
        }
    },
]
