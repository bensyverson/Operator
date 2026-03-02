//
//  ChatState+Operative.swift
//  Chat
//
//  Created by Ben Syverson on 2026-03-02.
//

import Foundation
import Operator
import TextUI

extension ChatState {
    /// Builds the Operative from the currently selected provider.
    func buildOperative() throws {
        let provider = ProviderOption.allCases[selectedProviderIndex]
        let systemPrompt = """
        You are a helpful assistant with access to time utilities, a calculator, \
        a key-value store, and system information tools. Use your tools to answer \
        the user's questions accurately. Be concise.
        """
        let tools: [any Operable] = [TimeTool(), KeyValueStore(), Calculator(), SystemInfo()]
        let budget = Budget(maxTurns: args.maxTurns)

        #if canImport(FoundationModels)
            if provider == .apple {
                guard #available(macOS 26.0, iOS 26.0, *) else {
                    providerWarning = "Apple Intelligence requires macOS 26.0+"
                    return
                }
                operative = try Operative(
                    name: "Chat",
                    description: "An interactive chat assistant",
                    systemPrompt: systemPrompt,
                    tools: tools,
                    budget: budget
                )
                return
            }
        #endif

        let llmProvider = try resolveProvider(provider)

        let resolvedModelType: ModelType = switch args.modelType {
        case "flagship": .flagship
        default: .fast
        }

        let resolvedInference: InferenceType = args.reasoningOff ? .direct : .reasoning

        let modelOverride: ModelName? = args.model.map {
            ModelName(rawValue: $0)
        }
        let config = ConversationConfiguration(
            modelType: resolvedModelType,
            inference: resolvedInference,
            model: modelOverride,
            maxTokens: 4096
        )

        operative = try Operative(
            name: "Chat",
            description: "An interactive chat assistant",
            provider: llmProvider,
            systemPrompt: systemPrompt,
            tools: tools,
            budget: budget,
            configuration: config
        )
    }
}
