//
//  ChatState+Provider.swift
//  Chat
//
//  Created by Ben Syverson on 2026-03-02.
//

import Foundation
import Operator
import TextUI

extension ChatState {
    func resolveProvider(_ provider: ProviderOption) throws -> Provider {
        let env = ProcessInfo.processInfo.environment

        // Custom host overrides provider selection
        if let host = args.host {
            guard let url = URL(string: host) else {
                throw OperativeError.configurationError("Invalid URL: '\(host)'")
            }
            let isOpenRouter = host.contains("openrouter.ai")
            let key = args.apiKey
                ?? (isOpenRouter ? env["OPENROUTER_API_KEY"] : nil)
                ?? env["OPENAI_API_KEY"]
            return .other(url, apiKey: key)
        }

        switch provider {
        case .anthropic:
            guard let key = args.apiKey ?? env["ANTHROPIC_API_KEY"] else {
                throw OperativeError.configurationError("Anthropic requires ANTHROPIC_API_KEY")
            }
            return .anthropic(apiKey: key)
        case .openai:
            guard let key = args.apiKey ?? env["OPENAI_API_KEY"] else {
                throw OperativeError.configurationError("OpenAI requires OPENAI_API_KEY")
            }
            return .openAI(apiKey: key)
        case .lmstudio:
            return .lmStudio
        case .apple:
            throw OperativeError.configurationError("Apple Intelligence not available on this platform")
        }
    }
}
