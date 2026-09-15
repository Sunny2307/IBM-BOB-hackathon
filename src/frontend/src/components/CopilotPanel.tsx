import { useState, type FormEvent } from "react";
import { askCopilot, ApiError } from "../api/client";
import { MOCK_COPILOT_RESPONSE } from "../api/mockData";
import type { ChatTurn, CopilotHistoryTurn } from "../api/types";
import { FormattedAnswer } from "./FormattedAnswer";

// Backend caps CopilotRequest.history at 20 messages (see schemas.py) —
// each turn becomes 2 messages, so keep at most the last 10 turns.
const MAX_HISTORY_TURNS = 10;

function toHistory(turns: ChatTurn[]): CopilotHistoryTurn[] {
  return turns.slice(-MAX_HISTORY_TURNS).flatMap((turn) => [
    { role: "user" as const, content: turn.question },
    { role: "assistant" as const, content: turn.answer },
  ]);
}

export function CopilotPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const [question, setQuestion] = useState("");
  const [history, setHistory] = useState<ChatTurn[]>([]);
  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    const trimmed = question.trim();
    if (!trimmed || isSending) return;

    setIsSending(true);
    setSendError(null);
    setQuestion("");

    try {
      const response = await askCopilot(trimmed, toHistory(history));
      setHistory((prev) => [
        ...prev,
        { question: trimmed, answer: response.answer, tool_calls: response.tool_calls },
      ]);
    } catch (err) {
      const message = err instanceof ApiError ? err.message : "Unknown error";
      setSendError(`${message} — showing a demo answer instead.`);
      setHistory((prev) => [
        ...prev,
        {
          question: trimmed,
          answer: MOCK_COPILOT_RESPONSE.answer,
          tool_calls: MOCK_COPILOT_RESPONSE.tool_calls,
        },
      ]);
    } finally {
      setIsSending(false);
    }
  }

  return (
    <>
      <button
        type="button"
        onClick={() => setIsOpen(true)}
        aria-label="Open copilot panel"
        className={`fixed top-1/2 right-0 z-[950] -translate-y-1/2 border border-r-0 border-carbon-gray-30 bg-carbon-white px-2 py-4 font-sans text-xs tracking-wider text-carbon-blue-60 uppercase transition-transform hover:bg-carbon-gray-10 shadow-sm ${
          isOpen ? "translate-x-full" : "translate-x-0"
        }`}
        style={{ writingMode: "vertical-rl" }}
      >
        Copilot
      </button>

      {/* Backdrop — click to close, fades with the drawer */}
      <div
        aria-hidden
        onClick={() => setIsOpen(false)}
        className={`fixed inset-0 z-[900] bg-carbon-gray-100/30 transition-opacity duration-300 ease-out ${
          isOpen ? "opacity-100" : "pointer-events-none opacity-0"
        }`}
      />

      <div
        role="complementary"
        aria-label="Copilot chat panel"
        className={`fixed inset-y-0 right-0 z-[1000] flex w-full max-w-md flex-col border-l border-carbon-gray-30 bg-carbon-gray-10 shadow-2xl transition-transform duration-300 ease-in-out will-change-transform ${
          isOpen ? "translate-x-0" : "translate-x-full"
        }`}
      >
        <header className="flex items-center justify-between border-b border-carbon-gray-30 bg-carbon-white px-4 py-3">
          <div className="flex items-center gap-3">
            <span className="h-2 w-2 animate-pulse rounded-full bg-carbon-blue-60" />
            <h2 className="font-sans text-sm font-semibold text-carbon-gray-100">
              Grid Copilot
            </h2>
          </div>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            aria-label="Close copilot panel"
            className="text-carbon-gray-60 hover:text-carbon-gray-100 transition-colors"
          >
            ✕
          </button>
        </header>

        <div className="flex-1 space-y-6 overflow-y-auto px-4 py-6">
          {history.length === 0 && (
            <p className="text-sm text-carbon-gray-70 bg-carbon-white p-4 border-l-4 border-carbon-gray-30 shadow-sm">
              Ask about at-risk assets, maintenance priorities, or weather-driven urgency.
              Answers are grounded in live backend/MCP tool calls.
            </p>
          )}

          {history.map((turn, i) => (
            <div key={i} className="space-y-3">
              <div className="flex justify-end">
                <div className="max-w-[85%] break-words rounded-sm bg-carbon-blue-60 px-4 py-3 text-sm text-carbon-white shadow-sm">
                  {turn.question}
                </div>
              </div>

              <div className="flex justify-start">
                <div className="max-w-[90%] break-words border-l-4 border-carbon-gray-30 bg-carbon-white px-4 py-3 text-sm text-carbon-gray-100 shadow-sm">
                  <FormattedAnswer text={turn.answer} />
                </div>
              </div>

              {turn.tool_calls.length > 0 && (
                <details className="mr-8 border border-carbon-gray-20 bg-carbon-white px-4 py-3 text-xs text-carbon-gray-70">
                  <summary className="cursor-pointer font-sans font-medium text-carbon-blue-60">
                    Tools called ({turn.tool_calls.length})
                  </summary>
                  <ul className="mt-3 space-y-2 font-mono">
                    {turn.tool_calls.map((call, j) => (
                      <li key={j} className="break-all text-[10px]">
                        <span className="font-bold text-carbon-gray-90">{call.tool}</span>
                        <br/>
                        {JSON.stringify(call.args)}
                      </li>
                    ))}
                  </ul>
                </details>
              )}
            </div>
          ))}

          {isSending && (
            <div className="mr-8 border-l-4 border-carbon-gray-30 bg-carbon-white px-4 py-3 text-sm text-carbon-gray-60 shadow-sm">
              <span className="animate-pulse">Thinking…</span>
            </div>
          )}

          {sendError && <p className="text-xs text-risk-medium font-medium">{sendError}</p>}
        </div>

        <form onSubmit={handleSubmit} className="flex border-t border-carbon-gray-30 bg-carbon-white">
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask the grid copilot…"
            className="flex-1 bg-transparent px-4 py-4 text-sm text-carbon-gray-100 placeholder:text-carbon-gray-60 focus:outline-none"
          />
          <button
            type="submit"
            disabled={isSending || !question.trim()}
            className="bg-carbon-blue-60 px-6 text-sm font-semibold text-carbon-white transition-colors hover:bg-carbon-blue-70 disabled:cursor-not-allowed disabled:bg-carbon-gray-20 disabled:text-carbon-gray-60"
          >
            Send
          </button>
        </form>
      </div>
    </>
  );
}
