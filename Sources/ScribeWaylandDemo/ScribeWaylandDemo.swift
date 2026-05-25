import Wayland
import ShapeTree
import ScribeCore
import Foundation
import Logging

// MARK: - Key mapping

private func keyCodeToChar(_ code: UInt) -> Character? {
    switch code {
    case 2: return "1"; case 3: return "2"; case 4: return "3"
    case 5: return "4"; case 6: return "5"; case 7: return "6"
    case 8: return "7"; case 9: return "8"; case 10: return "9"
    case 11: return "0"; case 12: return "-"; case 13: return "="
    case 16: return "q"; case 17: return "w"; case 18: return "e"
    case 19: return "r"; case 20: return "t"; case 21: return "y"
    case 22: return "u"; case 23: return "i"; case 24: return "o"
    case 25: return "p"; case 26: return "["; case 27: return "]"
    case 30: return "a"; case 31: return "s"; case 32: return "d"
    case 33: return "f"; case 34: return "g"; case 35: return "h"
    case 36: return "j"; case 37: return "k"; case 38: return "l"
    case 39: return ";"; case 40: return "'"
    case 43: return "\\"; case 86: return "\\"
    case 44: return "z"; case 45: return "x"; case 46: return "c"
    case 47: return "v"; case 48: return "b"; case 49: return "n"
    case 50: return "m"; case 51: return ","; case 52: return "."
    case 53: return "/"; case 57: return " "
    default:  return nil
    }
}

// MARK: - Text wrapping

/// Wraps text to fit within `maxChars` per line. Splits on word boundaries.
private func wrapText(_ text: String, maxChars: Int) -> [String] {
    guard maxChars > 0 else { return [text] }
    var lines: [String] = []
    var current = ""
    for word in text.split(separator: " ", omittingEmptySubsequences: false) {
        let wordStr = String(word)
        if current.isEmpty {
            current = wordStr
        } else if current.count + 1 + wordStr.count <= maxChars {
            current += " " + wordStr
        } else {
            lines.append(current)
            current = wordStr
        }
        // Handle words longer than maxChars by force-splitting
        while current.count > maxChars {
            let splitIdx = current.index(current.startIndex, offsetBy: maxChars)
            lines.append(String(current[..<splitIdx]))
            current = String(current[splitIdx...])
        }
    }
    if !current.isEmpty { lines.append(current) }
    return lines.isEmpty ? [""] : lines
}

// MARK: - Chat state actor (isolated from MainActor)

private actor ChatState {
    var lines: [String] = ["Scribe Wayland Demo - agent ready"]
    var inputBuffer: String = ""
    var modelBusy: Bool = false
    private var agent: ScribeAgent?
    private let logger = Logger(label: "chat.state")

    func setAgent(_ a: ScribeAgent) { agent = a }

    func appendChar(_ ch: Character) {
        inputBuffer.append(ch)
    }

    func backspace() {
        if !inputBuffer.isEmpty { inputBuffer.removeLast() }
    }

    func submit() -> String? {
        let text = inputBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        inputBuffer = ""
        guard !text.isEmpty, !modelBusy, let agent else { return nil }
        lines.append("> \(text)")
        modelBusy = true

        Task { [agent] in
            let stream = await agent.stream(text)
            var reply = ""
            var hasReply = false
            for await event in stream.events {
                switch event {
                case .output(let out):
                    if case .text(_, let t) = out {
                        reply += t
                        let display = "  \(reply)"  // assistant prefix
                        if !hasReply {
                            self.appendLine(display)
                            hasReply = true
                        } else {
                            self.updateLastLine(display)
                        }
                    }
                case .tool(let t):
                    if case .invocation(let n, _, let o) = t {
                        self.appendLine("  [\(n)] \(o)")
                    }
                case .lifecycle(let lc):
                    if case .error(let e) = lc {
                        self.appendLine("  Error: \(e.errorDescription ?? "?")")
                    }
                }
            }
            if !hasReply {
                self.appendLine("  (no response)")
            }
            self.setBusy(false)
        }
        return text
    }

    func snapshot() -> (lines: [String], input: String, busy: Bool) {
        (lines, inputBuffer, modelBusy)
    }

    private func appendLine(_ s: String) { lines.append(s) }
    private func updateLastLine(_ s: String) {
        if !lines.isEmpty { lines[lines.count - 1] = s }
    }
    private func setBusy(_ b: Bool) { modelBusy = b }
}

// MARK: - Screen

private struct MyScreen: Block {
    let lines: [String]
    let input: String
    let busy: Bool

    var layer: some Block {
        let maxChars = 55  // safe default for 800px window at scale(2)
        let wrapped: [String] = lines.flatMap { wrapText($0, maxChars: maxChars) }

        return Direction(.vertical) {
            // Banner
            Direction(.horizontal) {
                Text("Scribe")
                    .foreground(.white).padding(4).scale(2)
                Rect().width(.grow)
                Text(busy ? "thinking..." : "ready")
                    .foreground(.gray).padding(4).scale(2)
            }
            .background(.blue).width(.grow)

            // Transcript
            Direction(.vertical) {
                for line in wrapped.suffix(30) {
                    let color: Color = line.hasPrefix("> ") ? .cyan : .white
                    Text(line)
                        .foreground(color).scale(2)
                }
            }
            .width(.grow).height(.grow)
            .background(.black)

            // Input
            Direction(.horizontal) {
                Text("> " + input + (busy ? "" : "_"))
                    .foreground(.cyan).scale(2)
                Rect().width(.grow)
            }
            .background(.black).width(.grow)
        }
        .height(.grow).width(.grow)
    }
}

// MARK: - Main

@main
@MainActor
struct ScribeWaylandDemoEntry {
    static func main() async {
        await runScribeDemo()
    }
}

@MainActor
func runScribeDemo() async {
    let serverURL = ProcessInfo.processInfo.environment["SCRIBE_SERVER_URL"]
        ?? "http://localhost:11434"
    let modelName = ProcessInfo.processInfo.environment["SCRIBE_MODEL"]
        ?? "gemma4:e2b"

    let config = ScribeConfig(
        agentModel: modelName,
        contextWindow: 128000,
        contextWindowThreshold: 0.8,
        serverURL: serverURL,
        apiKey: nil,
        tools: [],
        workingDirectory: FileManager.default.currentDirectoryPath,
        reasoningEnabled: nil
    )

    let agentLogger = Logger(label: "scribe.agent")
    let agent: ScribeAgent
    do {
        agent = try ScribeAgent(
            configuration: config,
            systemPrompt: "You are a helpful AI assistant. Keep responses concise.",
            logger: agentLogger
        )
    } catch {
        print("Failed to create ScribeAgent: \(error)")
        return
    }

    let chat = ChatState()
    await chat.setAgent(agent)

    Wayland.setup()

    event_loop: for await ev in Wayland.events() {
        switch ev {
        case .frame:
            let (lines, input, busy) = await chat.snapshot()
            Wayland.preDraw()
            Wayland.render(MyScreen(lines: lines, input: input, busy: busy))
            Wayland.postDraw()

        case .key(let code, let state):
            guard state == 1 else { continue }
            switch code {
            case 1:  Wayland.exit(); break event_loop
            case 28: let _ = await chat.submit()
            case 14: await chat.backspace()
            default:
                if let ch = keyCodeToChar(code) { await chat.appendChar(ch) }
            }
        }
    }
}
