import { useEffect, useRef, useState, type FormEvent } from "react";
import { askCopilot, ApiError } from "../api/client";
import { MOCK_COPILOT_RESPONSE } from "../api/mockData";
import type { ChatTurn } from "../api/types";

/* ─── Three-dot typing indicator ───────────────────── */
function TypingIndicator() {
  return (
    <div
      className="flex items-center gap-1.5 px-4 py-3 rounded-sm"
      style={{
        backgroundColor: "var(--color-surface-2)",
        border: "1px solid var(--color-border-subtle)",
      }}
      aria-label="Thinking…"
      role="status"
    >
      {[0, 0.2, 0.4].map((delay, i) => (
        <span
          key={i}
          className="block rounded-full"
          style={{
            width: 6,
            height: 6,
            backgroundColor: "var(--color-accent)",
            animation: `var(--animate-dot-bounce)`,
            animationDelay: `${delay}s`,
          }}
          aria-hidden="true"
        />
      ))}
    </div>
  );
}

/* ─── Main panel ────────────────────────────────────── */
export function CopilotPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const [question, setQuestion] = useState("");
  const [history, setHistory] = useState<ChatTurn[]>([]);
  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  /* Auto-scroll to bottom on new message */
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [history, isSending]);

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
        {
          question: trimmed,
          answer: response.answer,
          tool_calls: response.tool_calls,
        },
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
      {/* ── Trigger pill button (Fitts' Law — 48px+ target) ── */}
      <button
        type="button"
        onClick={() => setIsOpen(true)}
        aria-label="Open AI copilot"
        style={{
          position: "fixed",
          top: "50%",
          right: 0,
          transform: isOpen ? "translate(100%, -50%)" : "translate(0, -50%)",
          zIndex: 40,
          display: "flex",
          alignItems: "center",
          gap: 6,
          padding: "12px 10px",
          backgroundColor: "var(--color-surface-2)",
          border: "1px solid var(--color-border-default)",
          borderRight: "none",
          borderRadius: "4px 0 0 4px",
          cursor: "pointer",
          transition: "transform 300ms ease-out, background-color 150ms",
          writingMode: "vertical-rl",
        }}
        onMouseEnter={(e) => {
          (e.currentTarget as HTMLButtonElement).style.backgroundColor =
            "var(--color-surface-3)";
        }}
        onMouseLeave={(e) => {
          (e.currentTarget as HTMLButtonElement).style.backgroundColor =
            "var(--color-surface-2)";
        }}
      >
        {/* AI sparkle icon */}
        <svg
          width="14"
          height="14"
          viewBox="0 0 14 14"
          fill="none"
          aria-hidden="true"
          style={{ flexShrink: 0, transform: "rotate(90deg)" }}
        >
          <path
            d="M7 1L8.5 5.5H13L9.5 8L11 12.5L7 10L3 12.5L4.5 8L1 5.5H5.5L7 1Z"
            fill="var(--color-accent)"
          />
        </svg>
        <span
          style={{
            fontFamily: "var(--font-sans)",
            fontSize: 11,
            fontWeight: 600,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            color: "var(--color-text-secondary)",
          }}
        >
          Copilot
        </span>
      </button>

      {/* ── Backdrop ── */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40"
          style={{ backgroundColor: "rgba(0 0 0 / 0.4)" }}
          onClick={() => setIsOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* ── Slide-in panel (glass over dark backdrop) ── */}
      <div
        role="complementary"
        aria-label="Copilot chat panel"
        className="fixed top-0 right-0 z-50 flex h-full w-full max-w-md flex-col"
        style={{
          transform: isOpen ? "translateX(0)" : "translateX(100%)",
          transition: "transform 300ms ease-out",
          backgroundColor: "hsl(220 14% 10% / 0.97)",
          backdropFilter: "blur(16px)",
          borderLeft: "1px solid var(--color-border-default)",
        }}
      >
        {/* Header */}
        <header
          className="flex items-center justify-between px-5 py-4"
          style={{ borderBottom: "1px solid var(--color-border-subtle)" }}
        >
          <div className="flex items-center gap-3">
            {/* Live indicator */}
            <span
              className="relative flex h-2 w-2 shrink-0"
              aria-hidden="true"
            >
              <span
                className="absolute inline-flex h-full w-full rounded-full opacity-75"
                style={{
                  backgroundColor: "var(--color-accent)",
                  animation: "ping 1.5s ease-in-out infinite",
                }}
              />
              <span
                className="relative inline-flex rounded-full"
                style={{
                  width: 8,
                  height: 8,
                  backgroundColor: "var(--color-accent)",
                }}
              />
            </span>
            <h2
              className="font-sans text-sm font-semibold"
              style={{ color: "var(--color-text-primary)" }}
            >
              Grid Copilot
            </h2>
          </div>
          <button
            type="button"
            onClick={() => setIsOpen(false)}
            aria-label="Close copilot panel"
            className="transition-colors"
            style={{
              color: "var(--color-text-tertiary)",
              fontSize: 18,
              lineHeight: 1,
              padding: "4px 8px",
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLButtonElement).style.color =
                "var(--color-text-primary)";
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLButtonElement).style.color =
                "var(--color-text-tertiary)";
            }}
          >
            ✕
          </button>
        </header>

        {/* Chat area */}
        <div
          ref={scrollRef}
          className="flex-1 overflow-y-auto space-y-4 px-4 py-5"
        >
          {/* Empty state hint */}
          {history.length === 0 && (
            <div
              className="rounded-sm px-4 py-4"
              style={{
                backgroundColor: "var(--color-surface-2)",
                border: "1px solid var(--color-border-subtle)",
                borderLeft: "3px solid var(--color-border-default)",
              }}
            >
              <p
                className="font-sans text-sm"
                style={{ color: "var(--color-text-secondary)" }}
              >
                Ask about at-risk assets, maintenance priorities, or
                weather-driven urgency. Answers are grounded in live backend/MCP
                tool calls.
              </p>
            </div>
          )}

          {/* Chat turns */}
          {history.map((turn, i) => (
            <div key={i} className="space-y-2">
              {/* User message — right-aligned blue chip */}
              <div className="flex justify-end">
                <div
                  className="max-w-[85%] rounded-sm px-4 py-3 font-sans text-sm"
                  style={{
                    backgroundColor: "var(--color-accent-dim)",
                    border: "1px solid rgba(15 98 254 / 0.3)",
                    color: "var(--color-text-primary)",
                  }}
                >
                  {turn.question}
                </div>
              </div>

              {/* AI message — left-aligned dark card */}
              <div
                className="max-w-[90%] rounded-sm px-4 py-3 font-sans text-sm"
                style={{
                  backgroundColor: "var(--color-surface-2)",
                  border: "1px solid var(--color-border-default)",
                  borderLeft: "3px solid var(--color-accent)",
                  color: "var(--color-text-primary)",
                  lineHeight: 1.6,
                }}
              >
                {turn.answer}
              </div>

              {/* Tool calls — collapsible */}
              {turn.tool_calls.length > 0 && (
                <details
                  className="max-w-[90%] rounded-sm px-4 py-3"
                  style={{
                    backgroundColor: "var(--color-surface-1)",
                    border: "1px solid var(--color-border-subtle)",
                  }}
                >
                  <summary
                    className="cursor-pointer font-sans text-xs font-semibold"
                    style={{ color: "var(--color-accent)" }}
                  >
                    Tools called ({turn.tool_calls.length})
                  </summary>
                  <ul className="mt-3 space-y-2 font-mono">
                    {turn.tool_calls.map((call, j) => (
                      <li
                        key={j}
                        className="break-all text-[10px]"
                        style={{ color: "var(--color-text-secondary)" }}
                      >
                        <span
                          className="font-bold"
                          style={{ color: "var(--color-text-primary)" }}
                        >
                          {call.tool}
                        </span>
                        <br />
                        {JSON.stringify(call.args)}
                      </li>
                    ))}
                  </ul>
                </details>
              )}
            </div>
          ))}

          {/* Typing indicator */}
          {isSending && <TypingIndicator />}

          {/* Send error */}
          {sendError && (
            <p
              className="font-sans text-xs"
              style={{ color: "var(--color-risk-medium)" }}
            >
              {sendError}
            </p>
          )}
        </div>

        {/* Input form */}
        <form
          onSubmit={handleSubmit}
          className="flex items-stretch"
          style={{ borderTop: "1px solid var(--color-border-subtle)" }}
        >
          <input
            type="text"
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            placeholder="Ask the grid copilot…"
            className="flex-1 bg-transparent font-sans text-sm focus:outline-none"
            style={{
              padding: "14px 16px",
              color: "var(--color-text-primary)",
              caretColor: "var(--color-accent)",
            }}
          />
          <button
            type="submit"
            disabled={isSending || !question.trim()}
            className="font-sans text-sm font-semibold transition-colors"
            style={{
              padding: "0 20px",
              backgroundColor:
                isSending || !question.trim()
                  ? "var(--color-surface-2)"
                  : "var(--color-accent)",
              color:
                isSending || !question.trim()
                  ? "var(--color-text-tertiary)"
                  : "#fff",
              cursor: isSending || !question.trim() ? "not-allowed" : "pointer",
              borderLeft: "1px solid var(--color-border-subtle)",
            }}
          >
            Send
          </button>
        </form>
      </div>
    </>
  );
}
