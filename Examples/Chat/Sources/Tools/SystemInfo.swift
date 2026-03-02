import Foundation
import Operator

#if canImport(FoundationModels)
    import FoundationModels
#endif

struct SystemInfo: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(name: "System Info", description: "Query system information") {
            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getHostname",
                    description: "Get the hostname of this machine",
                    input: GetHostnameInput.self
                ) { _ in
                    ToolOutput(ProcessInfo.processInfo.hostName)
                }
            #else
                Tool(name: "getHostname", description: "Get the hostname of this machine") {
                    ToolOutput(ProcessInfo.processInfo.hostName)
                }
            #endif

            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getOS",
                    description: "Get the operating system name and version",
                    input: GetOSInput.self
                ) { _ in
                    osOutput()
                }
            #else
                Tool(name: "getOS", description: "Get the operating system name and version") {
                    osOutput()
                }
            #endif

            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getUptime",
                    description: "Get the system uptime",
                    input: GetUptimeInput.self
                ) { _ in
                    uptimeOutput()
                }
            #else
                Tool(name: "getUptime", description: "Get the system uptime") {
                    uptimeOutput()
                }
            #endif

            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getUser",
                    description: "Get the current username",
                    input: GetUserInput.self
                ) { _ in
                    userOutput()
                }
            #else
                Tool(name: "getUser", description: "Get the current username") {
                    userOutput()
                }
            #endif

            // swiftlint:disable:next force_try
            try! Tool(
                name: "getEnvVar",
                description: "Get the value of an environment variable",
                input: EnvVarInput.self
            ) { input in
                if let value = ProcessInfo.processInfo.environment[input.name] {
                    ToolOutput("\(input.name)=\(value)")
                } else {
                    ToolOutput("Environment variable '\(input.name)' is not set.")
                }
            }
        }
    }

    #if canImport(FoundationModels)
        @Generable
    #endif
    struct EnvVarInput: ToolInput {
        #if canImport(FoundationModels)
            @Guide(description: "The name of the environment variable to read")
        #endif
        var name: String

        static var paramDescriptions: [String: String] {
            [
                "name": "The name of the environment variable to read",
            ]
        }
    }
}

// MARK: - Helper functions

private func osOutput() -> ToolOutput {
    let info = ProcessInfo.processInfo
    let version = info.operatingSystemVersion
    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    #if os(macOS)
        return ToolOutput("macOS \(versionString)")
    #elseif os(Linux)
        return ToolOutput("Linux \(versionString)")
    #else
        return ToolOutput("Unknown OS \(versionString)")
    #endif
}

private func uptimeOutput() -> ToolOutput {
    let uptime = ProcessInfo.processInfo.systemUptime
    let hours = Int(uptime) / 3600
    let minutes = (Int(uptime) % 3600) / 60
    return ToolOutput("\(hours)h \(minutes)m")
}

private func userOutput() -> ToolOutput {
    #if os(macOS)
        let user = ProcessInfo.processInfo.userName
    #else
        let user = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
    #endif
    return ToolOutput(user)
}

// MARK: - Noop Inputs (FoundationModels only)

#if canImport(FoundationModels)
    @Generable
    struct GetHostnameInput: ToolInput {
        @Guide(description: "Whether to include domain (ignored, always returns full hostname)")
        var verbose: Bool?

        static var paramDescriptions: [String: String] {
            ["verbose": "Whether to include domain (ignored)"]
        }
    }

    @Generable
    struct GetOSInput: ToolInput {
        @Guide(description: "Whether to include build number (ignored)")
        var verbose: Bool?

        static var paramDescriptions: [String: String] {
            ["verbose": "Whether to include build number (ignored)"]
        }
    }

    @Generable
    struct GetUptimeInput: ToolInput {
        @Guide(description: "Whether to include seconds (ignored)")
        var verbose: Bool?

        static var paramDescriptions: [String: String] {
            ["verbose": "Whether to include seconds (ignored)"]
        }
    }

    @Generable
    struct GetUserInput: ToolInput {
        @Guide(description: "Whether to include full name (ignored)")
        var verbose: Bool?

        static var paramDescriptions: [String: String] {
            ["verbose": "Whether to include full name (ignored)"]
        }
    }
#endif
