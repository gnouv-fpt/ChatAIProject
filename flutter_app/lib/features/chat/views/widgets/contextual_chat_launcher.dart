import 'package:flutter/material.dart';

import '../../../../widgets/ask_ai_button.dart';
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
    this.showLabel,
  });

  final String curriculumId;
  final String contextKey;
  final String title;
  final String contextHint;
  final int? semesterNumber;
  final List<String>? suggestedQuestions;
  final bool? showLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? open = curriculumId.isEmpty
        ? null
        : () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.65,
                  minChildSize: 0.45,
                  maxChildSize: 0.92,
                  snap: true,
                  snapSizes: const [0.65, 0.92],
                  expand: false,
                  builder: (ctx, scrollController) => ContextualChatPanel(
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

    return AskAiButton(
      onPressed: open,
      compact: showLabel != null ? !showLabel! : null,
      tooltip: 'Hỏi trợ lý về $title',
    );
  }
}
