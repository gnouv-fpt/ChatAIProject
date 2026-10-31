import 'package:flutter/material.dart';

import 'contextual_chat_panel.dart';

class ContextualChatLauncher extends StatelessWidget {
  const ContextualChatLauncher({
    super.key,
    required this.curriculumId,
    required this.contextKey,
    required this.title,
    required this.contextHint,
    this.semesterNumber,
    this.suggestedQuestions,
    this.showLabel = false,
  });

  final String curriculumId;
  final String contextKey;
  final String title;
  final String contextHint;
  final int? semesterNumber;
  final List<String>? suggestedQuestions;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? open = curriculumId.isEmpty
        ? null
        : () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (sheetContext) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(sheetContext).height * 0.85,
                  child: ContextualChatPanel(
                    scope: 'curriculum',
                    scopeId: '$curriculumId:$contextKey',
                    backendScopeId: curriculumId,
                    contextHint: contextHint,
                    title: title,
                    subtitle: contextHint,
                    semesterNumber: semesterNumber,
                    suggestedQuestions: suggestedQuestions,
                    onClose: () => Navigator.pop(sheetContext),
                  ),
                ),
              ),
            );
          };
    if (showLabel) {
      return Tooltip(
        message: 'Hỏi Trợ lý về $title',
        child: TextButton.icon(
          onPressed: open,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Hỏi trợ lý'),
        ),
      );
    }
    return IconButton(
      tooltip: 'Hỏi Trợ lý về $title',
      icon: const Icon(Icons.auto_awesome_outlined),
      onPressed: open,
    );
  }
}
