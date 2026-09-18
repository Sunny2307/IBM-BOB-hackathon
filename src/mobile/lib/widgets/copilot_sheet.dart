import 'dart:convert';

import 'package:flutter/material.dart';

import '../api/types.dart';
import '../state/copilot_controller.dart';
import '../theme/app_theme.dart';
import 'formatted_answer.dart';

/// Port of the web frontend's `CopilotPanel` right-hand drawer. On mobile the
/// drawer becomes a near-full-height modal sheet, which is the phone-native
/// equivalent of a side panel.
Future<void> showCopilotSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.gray10,
    shape: const RoundedRectangleBorder(),
    builder: (_) => const _CopilotSheet(),
  );
}

class _CopilotSheet extends StatefulWidget {
  const _CopilotSheet();

  @override
  State<_CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends State<_CopilotSheet> {
  final _controller = CopilotController.instance;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    // Keep the newest message (and the "Thinking…" indicator) in view.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send(String raw) async {
    if (raw.trim().isEmpty || _controller.isSending) return;
    _inputController.clear();
    await _controller.ask(raw);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final history = _controller.history;

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.9,
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  if (history.isEmpty) _intro(),
                  for (final turn in history) ...[
                    _questionBubble(turn.question),
                    const SizedBox(height: 12),
                    _answerBubble(turn.answer),
                    if (turn.toolCalls.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _toolCalls(turn.toolCalls),
                    ],
                    const SizedBox(height: 24),
                  ],
                  if (_controller.isSending) _thinking(),
                  if (_controller.sendError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _controller.sendError!,
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.riskMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              color: AppColors.blue60,
              child: const Icon(Icons.bolt, size: 18, color: AppColors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Volt',
                  style: AppText.serif(size: 16, weight: FontWeight.w600),
                ),
                Text('GRID COPILOT', style: AppText.kicker()),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.gray60),
              tooltip: 'Close Volt panel',
            ),
          ],
        ),
      );

  Widget _intro() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                left: BorderSide(color: AppColors.gray30, width: 2),
              ),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "Hi, I'm "),
                  TextSpan(
                    text: 'Volt',
                    style: AppText.serif(
                      size: 15,
                      weight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' — ask me about at-risk assets, maintenance priorities, '
                        'or weather-driven urgency. Answers are grounded in live '
                        'backend/MCP tool calls, never guessed.',
                  ),
                ],
              ),
              style: AppText.serif(
                size: 15,
                color: AppColors.gray70,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final question in CopilotController.suggestedQuestions)
                InkWell(
                  onTap: () => _send(question),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      border: Border.all(color: AppColors.gray30),
                    ),
                    child: Text(
                      question,
                      style: AppText.sans(size: 12, color: AppColors.blue70),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );

  Widget _questionBubble(String question) => Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: Container(
            color: AppColors.blue60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              question,
              style: AppText.sans(size: 14, color: AppColors.white),
            ),
          ),
        ),
      );

  Widget _answerBubble(String answer) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(left: BorderSide(color: AppColors.gray30, width: 2)),
        ),
        child: FormattedAnswer(text: answer),
      );

  Widget _toolCalls(List<ToolCall> calls) => Container(
        margin: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.gray20),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Text(
              'Tools called (${calls.length})',
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.blue60,
              ),
            ),
            children: [
              for (final call in calls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.tool,
                        style: AppText.mono(
                          size: 11,
                          weight: FontWeight.w700,
                          color: AppColors.gray90,
                        ),
                      ),
                      Text(
                        jsonEncode(call.args),
                        style: AppText.mono(size: 10, color: AppColors.gray70),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _thinking() => Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(left: BorderSide(color: AppColors.gray30, width: 2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.blue60,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Volt is thinking…',
              style: AppText.sans(size: 14, color: AppColors.gray60),
            ),
          ],
        ),
      );

  Widget _composer() {
    final canSend =
        !_controller.isSending && _inputController.text.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.gray20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                onChanged: (_) => setState(() {}),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
                style: AppText.sans(size: 14),
                decoration: InputDecoration(
                  hintText: 'Ask Volt about the grid…',
                  hintStyle: AppText.sans(size: 14, color: AppColors.gray60),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ),
            GestureDetector(
              onTap: canSend ? () => _send(_inputController.text) : null,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                color: canSend ? AppColors.blue60 : AppColors.gray20,
                child: Text(
                  'Send',
                  style: AppText.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: canSend ? AppColors.white : AppColors.gray60,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
