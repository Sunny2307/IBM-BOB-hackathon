import type { ReactNode } from "react";

// Small hand-rolled formatter for copilot answers: bold via **text** and
// bullet lists via lines starting with "- ". Intentionally not a markdown
// library — the LLM-backed answers only ever need this much structure.

function renderInline(text: string): ReactNode {
  const parts = text.split(/(\*\*[^*]+\*\*)/g).filter((p) => p !== "");
  return parts.map((part, i) =>
    part.startsWith("**") && part.endsWith("**") ? (
      <strong key={i} className="font-semibold text-carbon-gray-100">
        {part.slice(2, -2)}
      </strong>
    ) : (
      <span key={i}>{part}</span>
    ),
  );
}

export function FormattedAnswer({ text }: { text: string }) {
  const lines = text.split(/\r?\n/);
  const blocks: ReactNode[] = [];
  let currentList: string[] = [];

  const flushList = () => {
    if (currentList.length === 0) return;
    blocks.push(
      <ul key={`ul-${blocks.length}`} className="list-disc space-y-1 pl-5">
        {currentList.map((item, i) => (
          <li key={i}>{renderInline(item)}</li>
        ))}
      </ul>,
    );
    currentList = [];
  };

  lines.forEach((rawLine, i) => {
    const trimmed = rawLine.trim();
    if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
      currentList.push(trimmed.slice(2));
      return;
    }
    flushList();
    if (trimmed.length === 0) return;
    blocks.push(
      <p key={`p-${i}`} className="leading-relaxed">
        {renderInline(trimmed)}
      </p>,
    );
  });
  flushList();

  if (blocks.length === 0) return null;
  return <div className="space-y-2">{blocks}</div>;
}
