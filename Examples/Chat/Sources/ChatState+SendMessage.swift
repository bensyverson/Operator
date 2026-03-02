//
//  ChatState+SendMessage.swift
//  Chat
//
//  Created by Ben Syverson on 2026-03-02.
//

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

        let stream: OperationStream = if let convo = lastConversation {
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
                messages.append(ChatMessage(
                    id: UUID(),
                    role: .toolOutput,
                    text: output.content,
                    toolName: req.name,
                    toolOutput: output.content
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
