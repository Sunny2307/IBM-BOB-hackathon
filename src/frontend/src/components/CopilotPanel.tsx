import { useState, type FormEvent } from "react";
import { askCopilot, ApiError } from "../api/client";
import { MOCK_COPILOT_RESPONSE } from "../api/mockData";
import type { ChatTurn } from "../api/types";

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
      const response = await askCopilot(trimmed);
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
        className={`fixed top-1/2 right-0 z-40 -translate-y-1/2 border border-r-0 border-signal/50 bg-console-900 px-2 py-4 font-mono text-xs tracking-[0.2em] text-signal uppercase transition-transform hover:bg-console-800 ${
          isOpen ? "translate-x-full" : "translate-x-0"
        }`}
        style={{ writingMode: "vertical-rl" }}
      >
        Copilot
      </button>

      <div
        role="complementary"
        aria-label="Copilot chat panel"
        className={`fixed top-0 right-0 z-50 flex h-full w-full max-w-md flex-col border-l border-console-700 bg-console-900 shadow-2xl transition-transform duration-300 ease-out ${
          isOpen ? "translate-x-0" : "translate-x-full"
        }`}
      >
        <header className="flex items-center justify-between border-b border-console-700 bg-console-850 px-4 py-3">
          <div className="flex items-center gap-2">
            <span className="h-2 w-2 animate-pulse bg-signal" />
            <h2 className="font-mono text-sm font-semibold tracking-widest text-slate-100 uppercase">
              Grid Copilot
            </h2>
          </div>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            aria-label="Close copilot panel"
            className="text-slate-400 hover:text-slate-100"
          >
            ✕
          </button>
        </header>

        <div className="flex-1 space-y-4 overflow-y-auto px-4 py-4">
          {history.length === 0 && (
            <p className="text-sm text-slate-500">
              Ask about at-risk assets, maintenance priorities, or weather-driven urgency.
              Answers are grounded in live backend/MCP tool calls.
            </p>
          )}

          {history.map((turn, i) => (
            <div key={i} className="space-y-2">
              <div className="ml-6 border border-console-700 bg-console-800 px-3 py-2 text-sm text-slate-200">
                {turn.question}
              </div>

              <div className="border-l-2 border-signal bg-console-850 px-3 py-2 text-sm text-slate-100">
                {turn.answer}
              </div>

              {turn.tool_calls.length > 0 && (
                <details className="border border-console-700 bg-console-900 px-3 py-2 text-xs text-slate-400">
                  <summary className="cursor-pointer font-mono text-signal">
                    Tools called ({turn.tool_calls.length})
                  </summary>
                  <ul className="mt-2 space-y-1 font-mono">
                    {turn.tool_calls.map((call, j) => (
                      <li key={j} className="break-all">
                        {call.tool}({JSON.stringify(call.args)})
                      </li>
                    ))}
                  </ul>
                </details>
              )}
            </div>
          ))}

          {isSending && (
            <div className="border-l-2 border-console-600 bg-console-850 px-3 py-2 text-sm text-slate-500">
              <span className="animate-pulse">Thinking…</span>
            </div>
          )}

          {sendError && <p className="text-xs text-risk-medium">{sendError}</p>}
        </div>

        <form onSubmit={handleSubmit} className="flex border-t border-console-700">
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask the grid copilot…"
            className="flex-1 bg-console-900 px-3 py-3 text-sm text-slate-100 placeholder:text-slate-600 focus:outline-none"
          />
          <button
            type="submit"
            disabled={isSending || !question.trim()}
            className="bg-signal px-4 text-sm font-semibold text-console-950 disabled:cursor-not-allowed disabled:bg-console-700 disabled:text-slate-500"
          >
            Send
          </button>
        </form>
      </div>
    </>
  );
}
