import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Small hand-rolled formatter for copilot answers: bold via **text** and
// bullet lists via lines starting with "- ". Intentionally not a markdown
// library — the LLM-backed answers only ever need this much structure.
// Port of the web frontend's `FormattedAnswer.tsx`.

/// A markdown table separator row: |---|:---:|---|  (dashes/colons only per cell)
final RegExp _tableSeparator =
    RegExp(r'^\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?$');

List<String> _splitTableRow(String line) => line
    .trim()
    .replaceFirst(RegExp(r'^\|'), '')
    .replaceFirst(RegExp(r'\|$'), '')
    .split('|')
    .map((cell) => cell.trim())
    .toList();

List<InlineSpan> _renderInline(String text, TextStyle baseStyle) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*([^*]+)\*\*');
  var cursor = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(
      TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor)));
  }
  return spans;
}

class FormattedAnswer extends StatelessWidget {
  const FormattedAnswer({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = AppText.serif(size: 15, height: 1.5);
    final lines = text.split(RegExp(r'\r?\n'));
    final blocks = <Widget>[];
    var currentList = <String>[];

    void flushList() {
      if (currentList.isEmpty) return;
      final items = List<String>.from(currentList);
      currentList = [];
      blocks.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.gray70,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: _renderInline(item, baseStyle)),
                        style: baseStyle,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }

    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();

      // Defense-in-depth: the system prompt tells the LLM never to use
      // markdown tables, but if one slips through anyway, render it as a
      // real table instead of leaving raw "| a | b |" on screen.
      if (trimmed.startsWith('|') &&
          i + 1 < lines.length &&
          _tableSeparator.hasMatch(lines[i + 1].trim())) {
        final header = _splitTableRow(trimmed);
        final dataRows = <List<String>>[];
        var j = i + 2;
        while (j < lines.length && lines[j].trim().startsWith('|')) {
          dataRows.add(_splitTableRow(lines[j]));
          j++;
        }
        flushList();
        blocks.add(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 30,
              dataRowMaxHeight: 44,
              horizontalMargin: 0,
              columnSpacing: 20,
              columns: [
                for (final cell in header)
                  DataColumn(
                    label: Text(
                      cell,
                      style:
                          AppText.sans(size: 12, weight: FontWeight.w600),
                    ),
                  ),
              ],
              rows: [
                for (final row in dataRows)
                  DataRow(
                    cells: [
                      for (var c = 0; c < header.length; c++)
                        DataCell(
                          Text(
                            c < row.length ? row[c] : '',
                            style: AppText.sans(size: 12),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
        i = j - 1;
        continue;
      }

      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        currentList.add(trimmed.substring(2));
        continue;
      }

      flushList();
      if (trimmed.isEmpty) continue;
      blocks.add(
        Text.rich(
          TextSpan(children: _renderInline(trimmed, baseStyle)),
          style: baseStyle,
        ),
      );
    }
    flushList();

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == blocks.length - 1 ? 0 : 12),
            child: blocks[i],
          ),
      ],
    );
  }
}
