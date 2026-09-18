import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../api/mock_data.dart';
import '../api/types.dart';

/// Holds the Volt conversation for the whole app session.
///
/// On the web, `CopilotPanel` is mounted once inside `Layout`, so its chat
/// history survives navigation between pages. The mobile panel is a modal
/// sheet that is built and torn down each time it opens, so the history lives
/// here instead — same behaviour, different mounting model.
class CopilotController extends ChangeNotifier {
  CopilotController._();

  static final CopilotController instance = CopilotController._();

  static const suggestedQuestions = [
    'Which assets are highest risk?',
    'Why is AST-014 risky?',
    "What's the maintenance plan for Eastgate?",
  ];

  final List<ChatTurn> _history = [];
  bool _isSending = false;
  String? _sendError;

  List<ChatTurn> get history => List.unmodifiable(_history);

  bool get isSending => _isSending;

  String? get sendError => _sendError;

  List<CopilotHistoryTurn> _historyPayload() {
    final recent = _history.length > maxCopilotHistoryTurns
        ? _history.sublist(_history.length - maxCopilotHistoryTurns)
        : _history;
    return [
      for (final turn in recent) ...[
        CopilotHistoryTurn(role: 'user', content: turn.question),
        CopilotHistoryTurn(role: 'assistant', content: turn.answer),
      ],
    ];
  }

  Future<void> ask(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || _isSending) return;

    _isSending = true;
    _sendError = null;
    notifyListeners();

    try {
      final response =
          await api.askCopilot(trimmed, history: _historyPayload());
      _history.add(
        ChatTurn(
          question: trimmed,
          answer: response.answer,
          toolCalls: response.toolCalls,
        ),
      );
    } catch (err) {
      final message = err is ApiError ? err.message : 'Unknown error';
      _sendError = '$message — showing a demo answer instead.';
      _history.add(
        ChatTurn(
          question: trimmed,
          answer: mockCopilotResponse.answer,
          toolCalls: mockCopilotResponse.toolCalls,
        ),
      );
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
}
