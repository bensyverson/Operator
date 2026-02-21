import Foundation
import Operator

struct TimeTool: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(name: "Time", description: "Time and date utilities", tools: [
            Tool(name: "getCurrentTime", description: "Get the current date and time") {
                ToolOutput(Date.now.formatted(date: .complete, time: .complete))
            },

            Tool(name: "getTimezone", description: "Get the current timezone, its abbreviation, and UTC offset") {
                let tz = TimeZone.current
                let offsetSeconds = tz.secondsFromGMT()
                let hours = offsetSeconds / 3600
                let minutes = abs(offsetSeconds % 3600) / 60
                let sign = hours >= 0 ? "+" : ""
                let offset = "UTC\(sign)\(hours)" + (minutes > 0 ? ":\(String(format: "%02d", minutes))" : "")
                return ToolOutput("\(tz.identifier) (\(tz.abbreviation() ?? "??")) \(offset)")
            },

            // swiftlint:disable:next force_try
            try! Tool(
                name: "dateMath",
                description: "Add or subtract a duration from a date. Use a negative value to subtract.",
                input: DateMathInput.self
            ) { input in
                let calendar = Calendar.current
                let referenceDate: Date
                if let from = input.from {
                    guard let parsed = try? Date(from, strategy: .iso8601) else {
                        return ToolOutput("Error: could not parse '\(from)' as an ISO 8601 date.")
                    }
                    referenceDate = parsed
                } else {
                    referenceDate = Date.now
                }
                guard let result = calendar.date(byAdding: input.unit.calendarComponent, value: input.value, to: referenceDate) else {
                    return ToolOutput("Error: could not compute the resulting date.")
                }
                return ToolOutput(result.formatted(date: .complete, time: .complete))
            },
        ])
    }
}

// MARK: - DateMathInput

struct DateMathInput: ToolInput {
    let value: Int
    let unit: DateUnit
    let from: String?

    static var paramDescriptions: [String: String] {
        [
            "value": "How many units to add (use a negative number to subtract)",
            "unit": "The calendar unit: days, hours, minutes, weeks, months, or years",
            "from": "An ISO 8601 date string to start from. Defaults to now if omitted.",
        ]
    }
}

// MARK: - DateUnit

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
