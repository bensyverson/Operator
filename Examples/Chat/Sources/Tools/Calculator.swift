import Foundation
import Operator

#if canImport(FoundationModels)
    import FoundationModels
#endif

struct Calculator: Operable {
    var toolGroup: ToolGroup {
        ToolGroup(name: "Calculator", description: "Basic arithmetic operations") {
            // swiftlint:disable:next force_try
            try! Tool(
                name: "calculate",
                description: "Perform a basic arithmetic operation on two numbers",
                input: CalculateInput.self
            ) { input in
                guard let result = compute(input) else {
                    return ToolOutput("Error: unknown operation '\(input.operation)'. Use +, -, *, /, or %.")
                }
                return ToolOutput(result)
            }
        }
    }

    #if canImport(FoundationModels)
        @Generable
    #endif
    struct CalculateInput: ToolInput {
        #if canImport(FoundationModels)
            @Guide(description: "The left-hand operand")
        #endif
        var lhs: Double

        #if canImport(FoundationModels)
            @Guide(description: "The right-hand operand")
        #endif
        var rhs: Double

        #if canImport(FoundationModels)
            @Guide(description: "The arithmetic operation: +, -, *, /, % (or add, subtract, multiply, divide, mod)")
        #endif
        var operation: String

        static var paramDescriptions: [String: String] {
            [
                "lhs": "The left-hand operand",
                "rhs": "The right-hand operand",
                "operation": "The arithmetic operation: +, -, *, /, % (or add, subtract, multiply, divide, mod)",
            ]
        }
    }
}

private func compute(_ input: Calculator.CalculateInput) -> String? {
    switch input.operation.lowercased() {
    case "+", "add", "plus", "sum", "addition":
        return format(input.lhs + input.rhs)
    case "-", "subtract", "minus", "difference", "subtraction":
        return format(input.lhs - input.rhs)
    case "*", "multiply", "times", "product", "multiplication":
        return format(input.lhs * input.rhs)
    case "/", "divide", "division":
        guard input.rhs != 0 else { return "Error: division by zero" }
        return format(input.lhs / input.rhs)
    case "%", "mod", "modulo", "remainder":
        guard input.rhs != 0 else { return "Error: division by zero" }
        return format(input.lhs.truncatingRemainder(dividingBy: input.rhs))
    default:
        return nil
    }
}

private func format(_ value: Double) -> String {
    if value == value.rounded(), !value.isInfinite, !value.isNaN {
        return String(format: "%.0f", value)
    }
    return String(value)
}
