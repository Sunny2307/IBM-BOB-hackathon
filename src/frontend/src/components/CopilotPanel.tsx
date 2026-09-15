import { useEffect, useRef, useState, type FormEvent } from "react";
import { askCopilot, ApiError } from "../api/client";
import { MOCK_COPILOT_RESPONSE } from "../api/mockData";
import type { ChatTurn, CopilotHistoryTurn } from "../api/types";
import { FormattedAnswer } from "./FormattedAnswer";

// Backend caps CopilotRequest.history at 20 messages (see schemas.py) —
// each turn becomes 2 messages, so keep at most the last 10 turns.
const MAX_HISTORY_TURNS = 10;

const SUGGESTED_QUESTIONS = [
  "Which assets are highest risk?",
  "Why is AST-014 risky?",
  "What's the maintenance plan for Eastgate?",
];

function BoltIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} fill="currentColor" aria-hidden>
      <path d="M13 2 3 14h7l-1 8 11-14h-7z" />
    </svg>
  );
}

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
  const scrollAnchorRef = useRef<HTMLDivElement>(null);

  // Keep the newest message (and the "Thinking…" indicator) in view —
  // without this, new content is appended below the fold and the panel
  // looks frozen until the user manually scrolls down.
  useEffect(() => {
    scrollAnchorRef.current?.scrollIntoView({ behavior: "smooth", block: "end" });
  }, [history, isSending]);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    await sendQuestion(question);
  }

  async function sendQuestion(raw: string) {
    const trimmed = raw.trim();
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
        aria-label="Open Volt, the grid copilot"
        className={`fixed right-6 bottom-6 z-[950] flex items-center gap-2 border border-carbon-gray-100 bg-carbon-blue-60 py-3 pr-5 pl-4 font-sans text-sm font-semibold text-carbon-white transition-all duration-200 hover:bg-carbon-blue-70 ${
          isOpen ? "pointer-events-none translate-y-3 opacity-0" : "translate-y-0 opacity-100"
        }`}
      >
        <BoltIcon className="h-4 w-4" />
        Ask Volt
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
        aria-label="Volt chat panel"
        className={`fixed inset-y-0 right-0 z-[1000] flex w-full max-w-md flex-col border-l border-carbon-gray-20 bg-carbon-gray-10 transition-transform duration-300 ease-in-out will-change-transform ${
          isOpen ? "translate-x-0" : "translate-x-full"
        }`}
      >
        <header className="flex items-center justify-between border-b border-carbon-gray-20 bg-carbon-white px-5 py-4">
          <div className="flex items-center gap-3">
            <span className="relative flex h-9 w-9 shrink-0 items-center justify-center bg-carbon-blue-60 text-carbon-white">
              <BoltIcon className="h-4 w-4" />
              <span className="absolute -right-0.5 -bottom-0.5 h-2 w-2 animate-pulse rounded-full bg-risk-low ring-2 ring-carbon-white" />
            </span>
            <div className="leading-tight">
              <h2 className="font-serif text-base font-semibold text-carbon-gray-100">Volt</h2>
              <p className="kicker">Grid Copilot</p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            aria-label="Close Volt panel"
            className="text-carbon-gray-60 hover:text-carbon-gray-100 transition-colors"
          >
            ✕
          </button>
        </header>

        <div className="flex-1 space-y-6 overflow-y-auto px-5 py-6">
          {history.length === 0 && (
            <div className="space-y-4">
              <p className="border-l-2 border-carbon-gray-30 bg-carbon-white p-4 font-serif text-[15px] text-carbon-gray-70 italic">
                Hi, I'm <strong className="font-semibold text-carbon-gray-100 not-italic">Volt</strong> —
                ask me about at-risk assets, maintenance priorities, or weather-driven urgency.
                Answers are grounded in live backend/MCP tool calls, never guessed.
              </p>
              <div className="flex flex-wrap gap-2">
                {SUGGESTED_QUESTIONS.map((q) => (
                  <button
                    key={q}
                    type="button"
                    onClick={() => sendQuestion(q)}
                    className="border border-carbon-gray-30 bg-carbon-white px-3 py-1.5 text-left text-xs text-carbon-blue-70 transition-colors hover:border-carbon-blue-60 hover:bg-carbon-blue-20 focus:outline-none focus:ring-2 focus:ring-carbon-blue-60"
                  >
                    {q}
                  </button>
                ))}
              </div>
            </div>
          )}

          {history.map((turn, i) => (
            <div key={i} className="space-y-3">
              <div className="flex justify-end">
                <div className="max-w-[85%] bg-carbon-blue-60 px-4 py-3 text-sm break-words text-carbon-white">
                  {turn.question}
                </div>
              </div>

              <div className="flex justify-start">
                <div className="max-w-[90%] border-l-2 border-carbon-gray-30 bg-carbon-white px-4 py-3 font-serif text-[15px] break-words text-carbon-gray-100">
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
            <div className="mr-8 flex items-center gap-2 border-l-2 border-carbon-gray-30 bg-carbon-white px-4 py-3 text-sm text-carbon-gray-60">
              <span className="flex gap-1" aria-hidden>
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-carbon-blue-60 [animation-delay:-0.3s]" />
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-carbon-blue-60 [animation-delay:-0.15s]" />
                <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-carbon-blue-60" />
              </span>
              Volt is thinking…
            </div>
          )}

          {sendError && <p className="text-xs text-risk-medium font-medium">{sendError}</p>}

          <div ref={scrollAnchorRef} />
        </div>

        <form onSubmit={handleSubmit} className="flex border-t border-carbon-gray-20 bg-carbon-white">
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask Volt about the grid…"
            className="flex-1 bg-transparent px-5 py-4 text-sm text-carbon-gray-100 placeholder:text-carbon-gray-60 focus:outline-none"
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
