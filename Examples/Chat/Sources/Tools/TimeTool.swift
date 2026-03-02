import Foundation
import Operator

#if canImport(FoundationModels)
    import FoundationModels
#endif

struct TimeTool: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(name: "Time", description: "Time and date utilities") {
            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getCurrentTime",
                    description: "Get the current date and time",
                    input: GetCurrentTimeInput.self
                ) { _ in
                    ToolOutput(Date.now.formatted(date: .complete, time: .complete))
                }
            #else
                Tool(name: "getCurrentTime", description: "Get the current date and time") {
                    ToolOutput(Date.now.formatted(date: .complete, time: .complete))
                }
            #endif

            #if canImport(FoundationModels)
                // swiftlint:disable:next force_try
                try! Tool(
                    name: "getTimezone",
                    description: "Get the current timezone, its abbreviation, and UTC offset",
                    input: GetTimezoneInput.self
                ) { _ in
                    timezoneOutput()
                }
            #else
                Tool(name: "getTimezone", description: "Get the current timezone, its abbreviation, and UTC offset") {
                    timezoneOutput()
                }
            #endif

            // swiftlint:disable:next force_try
            try! Tool(
                name: "dateMath",
                description: "Add or subtract a duration from a date to receive a full date and time. Use a negative value to subtract.",
                input: DateMathInput.self
            ) { input in
                let calendar = Calendar.current
                let referenceDate: Date
                if let from = input.from {
                    guard let parsed = parseDate(from) else {
                        return ToolOutput("Error: could not parse '\(from)' as a date.")
                    }
                    referenceDate = parsed
                } else {
                    referenceDate = Date.now
                }
                guard let result = calendar.date(byAdding: input.unit.calendarComponent, value: input.value, to: referenceDate) else {
                    return ToolOutput("Error: could not compute the resulting date.")
                }
                return ToolOutput(result.formatted(date: .complete, time: .complete))
            }
        }
    }
}

/// Liberally parses a date string from LLM output.
///
/// LLMs produce dates in many forms — full ISO 8601 with timezone, datetime
/// without timezone, date-only, or even natural language like "now" or
/// "today". This helper tries progressively looser strategies so the tool
/// works regardless of what the model sends.
private func parseDate(_ string: String) -> Date? {
    let trimmed = string.trimmingCharacters(in: .whitespaces).lowercased()

    // Natural language shortcuts
    switch trimmed {
    case "now": return Date.now
    case "today":
        return Calendar.current.startOfDay(for: Date.now)
    case "yesterday":
        return Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date.now))
    case "tomorrow":
        return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date.now))
    default:
        break
    }

    // Full ISO 8601 with timezone (e.g. 2026-03-02T15:21:00Z)
    if let date = try? Date(string, strategy: .iso8601) {
        return date
    }

    // Datetime without timezone (e.g. 2026-03-02T15:21:00) — treat as local time
    if string.contains("T") || string.contains(" "), string.count > 10 {
        let normalized = string.replacingOccurrences(of: " ", with: "T")
        let tz = TimeZone.current
        let offsetSeconds = tz.secondsFromGMT()
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let absOffset = abs(offsetSeconds)
        let h = absOffset / 3600
        let m = (absOffset % 3600) / 60
        let withTZ = normalized + String(format: "%@%02d:%02d", sign, h, m)
        if let date = try? Date(withTZ, strategy: .iso8601) {
            return date
        }
    }

    // Date-only (e.g. 2026-03-02) — treat as midnight local time
    if let _ = string.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) {
        let withTime = string + "T00:00:00"
        let tz = TimeZone.current
        let offsetSeconds = tz.secondsFromGMT()
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let absOffset = abs(offsetSeconds)
        let h = absOffset / 3600
        let m = (absOffset % 3600) / 60
        let withTZ = withTime + String(format: "%@%02d:%02d", sign, h, m)
        if let date = try? Date(withTZ, strategy: .iso8601) {
            return date
        }
    }

    // Last resort: DateFormatter with common formats
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    for format in ["yyyy-MM-dd HH:mm", "MMM d, yyyy", "MMMM d, yyyy"] {
        formatter.dateFormat = format
        if let date = formatter.date(from: string) {
            return date
        }
    }

    return nil
}

private func timezoneOutput() -> ToolOutput {
    let tz = TimeZone.current
    let offsetSeconds = tz.secondsFromGMT()
    let hours = offsetSeconds / 3600
    let minutes = abs(offsetSeconds % 3600) / 60
    let sign = hours >= 0 ? "+" : ""
    let offset = "UTC\(sign)\(hours)" + (minutes > 0 ? ":\(String(format: "%02d", minutes))" : "")
    return ToolOutput("\(tz.identifier) (\(tz.abbreviation() ?? "??")) \(offset)")
}

// MARK: - Noop Inputs (FoundationModels only)

#if canImport(FoundationModels)
    @Generable
    struct GetCurrentTimeInput: ToolInput {
        @Guide(description: "Output format (ignored, always returns full date/time)")
        var format: String?

        static var paramDescriptions: [String: String] {
            ["format": "Output format (ignored)"]
        }
    }

    @Generable
    struct GetTimezoneInput: ToolInput {
        @Guide(description: "Output format (ignored, always returns identifier and offset)")
        var format: String?

        static var paramDescriptions: [String: String] {
            ["format": "Output format (ignored)"]
        }
    }
#endif

// MARK: - DateMathInput

#if canImport(FoundationModels)
    @Generable
#endif
struct DateMathInput: ToolInput {
    #if canImport(FoundationModels)
        @Guide(description: "How many units to add (use a negative number to subtract)")
    #endif
    var value: Int

    #if canImport(FoundationModels)
        @Guide(description: "The calendar unit: days, hours, minutes, weeks, months, or years")
    #endif
    var unit: DateUnit

    #if canImport(FoundationModels)
        @Guide(description: "A date to start from (ISO 8601, date-only like 2026-03-02, or 'now'/'today'). Defaults to now if omitted.")
    #endif
    var from: String?

    static var paramDescriptions: [String: String] {
        [
            "value": "How many units to add (use a negative number to subtract)",
            "unit": "The calendar unit: days, hours, minutes, weeks, months, or years",
            "from": "A date to start from (ISO 8601, date-only like 2026-03-02, or 'now'/'today'/'yesterday'/'tomorrow'). Defaults to now if omitted.",
        ]
    }
}

// MARK: - DateUnit

#if canImport(FoundationModels)
    @Generable
#endif
enum DateUnit: String, Codable, Sendable, CaseIterable {
    case days, hours, minutes, weeks, months, years

    var calendarComponent: Calendar.Component {
        switch self {
        case .days: .day
        case .hours: .hour
        case .minutes: .minute
        case .weeks: .weekOfYear
        case .months: .month
        case .years: .year
        }
    }
}
