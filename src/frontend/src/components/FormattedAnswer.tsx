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

// A markdown table separator row: |---|:---:|---|  (dashes/colons only per cell)
const TABLE_SEPARATOR = /^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?$/;

function splitTableRow(line: string): string[] {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
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

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();

    // Defense-in-depth: the system prompt tells the LLM never to use
    // markdown tables (the chat can't render pipe syntax), but if one
    // slips through anyway, render it as a real table instead of leaving
    // raw "| a | b |" garbage on screen.
    if (
      trimmed.startsWith("|") &&
      lines[i + 1] &&
      TABLE_SEPARATOR.test(lines[i + 1].trim())
    ) {
      const header = splitTableRow(trimmed);
      const dataRows: string[][] = [];
      let j = i + 2;
      while (j < lines.length && lines[j].trim().startsWith("|")) {
        dataRows.push(splitTableRow(lines[j]));
        j++;
      }
      flushList();
      blocks.push(
        <div key={`table-${blocks.length}`} className="overflow-x-auto">
          <table className="w-full border-collapse text-xs">
            <thead>
              <tr>
                {header.map((cell, c) => (
                  <th
                    key={c}
                    className="border-b border-carbon-gray-30 px-2 py-1.5 text-left font-sans font-semibold text-carbon-gray-100"
                  >
                    {renderInline(cell)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-carbon-gray-20">
              {dataRows.map((row, r) => (
                <tr key={r}>
                  {row.map((cell, c) => (
                    <td key={c} className="px-2 py-1.5">
                      {renderInline(cell)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>,
      );
      i = j - 1;
      continue;
    }

    if (trimmed.startsWith("- ") || trimmed.startsWith("* ")) {
      currentList.push(trimmed.slice(2));
      continue;
    }
    flushList();
    if (trimmed.length === 0) continue;
    blocks.push(
      <p key={`p-${i}`} className="leading-relaxed">
        {renderInline(trimmed)}
      </p>,
    );
  }
  flushList();

  if (blocks.length === 0) return null;
  return <div className="space-y-3">{blocks}</div>;
}
