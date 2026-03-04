//
//  ChatState+SendMessage.swift
//  Chat
//
//  Created by Ben Syverson on 2026-03-02.
//

import ChatCore
import Foundation
import Operator
import TextUI

extension ChatState {
    /// Sends a user message and streams the agent's response.
    @MainActor
    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(id: UUID(), role: .user, text: trimmed))
        inputText = ""
        isStreaming = true
        currentTurn = 0
        pressureWarning = nil

        var currentAgentMsgID: UUID?

        guard let operative else {
            messages.append(ChatMessage(id: UUID(), role: .system, text: "No operative configured."))
            isStreaming = false
            return
        }

        // Use multimodal content parts unless the model explicitly lacks vision.
        // When model is nil (resolved at call time) or supportsVision is nil
        // (unknown), we optimistically try — all current Anthropic/OpenAI models
        // support vision, and sending images to a text-only model is harmless.
        let skipVision = operative.configuration.model?.supportsVision == false
        let multimodalParts = skipVision ? nil : trimmed.contentParts()

        let stream: OperationStream = if let parts = multimodalParts {
            if let convo = lastConversation {
                operative.run(parts, continuing: convo)
            } else {
                operative.run(parts)
            }
        } else if let convo = lastConversation {
            operative.run(trimmed, continuing: convo)
        } else {
            operative.run(trimmed)
        }

        for await op in stream {
            switch op {
            case let .text(chunk):
                if let id = currentAgentMsgID,
                   let idx = messages.firstIndex(where: { $0.id == id })
                {
                    messages[idx].text += chunk
                } else {
                    let msg = ChatMessage(id: UUID(), role: .agent, text: chunk)
                    currentAgentMsgID = msg.id
                    messages.append(msg)
                }

            case let .thinking(chunk):
                appendOrCreate(role: .thinking, chunk: chunk)

            case let .toolsRequested(reqs):
                for req in reqs {
                    messages.append(ChatMessage(
                        id: UUID(),
                        role: .toolCall,
                        text: req.name,
                        toolName: req.name,
                        toolArguments: req.arguments
                    ))
                }

            case let .toolCompleted(req, output):
                let outputText = output.textContent ?? "[media content]"
                messages.append(ChatMessage(
                    id: UUID(),
                    role: .toolOutput,
                    text: outputText,
                    toolName: req.name,
                    toolOutput: outputText
                ))

            case let .toolFailed(req, error):
                messages.append(ChatMessage(
                    id: UUID(),
                    role: .toolOutput,
                    text: "Error: \(error)",
                    toolName: req.name
                ))

            case let .turnStarted(ctx):
                currentTurn = ctx.turnNumber
                currentAgentMsgID = nil

            case let .turnCompleted(result):
                totalTokens = result.cumulativeUsage.totalTokens

            case let .pressure(info):
                pressureWarning = "\(info.dimension): \(Int(info.utilization * 100))%"

            case let .completed(result):
                lastConversation = result.conversation

            case let .stopped(reason):
                messages.append(ChatMessage(id: UUID(), role: .system, text: "Stopped: \(reason)"))

            default:
                break
            }
        }

        isStreaming = false
    }

    /// Appends a chunk to the most recent message of the given role,
    /// or creates a new message if the last message has a different role.
    private func appendOrCreate(role: MessageRole, chunk: String) {
        if let last = messages.last, last.role == role {
            let idx = messages.count - 1
            messages[idx].text += chunk
        } else {
            messages.append(ChatMessage(id: UUID(), role: role, text: chunk))
        }
    }
}
