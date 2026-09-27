import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import 'chat_bubble.dart';
import 'server_status_bar.dart';

class ContextualChatPanel extends StatefulWidget {
  final String scope; // 'curriculum' | 'subject'
  final String scopeId; // e.g. 'BIT_SE_K19B' or 'PRM393'
  final String title;
  final String? subtitle;
  final List<String>? suggestedQuestions;

  const ContextualChatPanel({
    super.key,
    required this.scope,
    required this.scopeId,
    required this.title,
    this.subtitle,
    this.suggestedQuestions,
  });

  @override
  State<ContextualChatPanel> createState() => _ContextualChatPanelState();
}

class _ContextualChatPanelState extends State<ContextualChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().updateScope(
            scope: widget.scope,
            id: widget.scopeId,
          );
    });
  }

  @override
  void didUpdateWidget(covariant ContextualChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope || oldWidget.scopeId != widget.scopeId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ChatProvider>().updateScope(
              scope: widget.scope,
              id: widget.scopeId,
            );
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(ChatProvider provider, String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    provider.sendPrompt(
      text,
      scope: widget.scope,
      id: widget.scopeId,
    );
    _scrollToBottom();
  }

  List<String> get _defaultSuggestions {
    if (widget.suggestedQuestions != null && widget.suggestedQuestions!.isNotEmpty) {
      return widget.suggestedQuestions!;
    }
    if (widget.scope == 'subject') {
      return [
        'Môn ${widget.scopeId} có thi PE không?',
        'Mục tiêu môn học (LOs) là gì?',
        'Cách học để đạt điểm cao môn này?',
        'Môn này có tính vào GPA không?',
      ];
    }
    return [
      'Khung ${widget.scopeId} có bao nhiêu tín chỉ?',
      'Học kỳ 5 có những môn nào?',
      'Môn PRM393 học ở kỳ mấy?',
      'Quy định hạ bậc tốt nghiệp khi học lại?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppTheme.slate200, width: 1.2)),
      ),
      child: Column(
        children: [
          // Header of Chat Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.slate200, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.slate900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.scope == 'subject'
                                  ? AppTheme.accentOrange.withOpacity(0.12)
                                  : AppTheme.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.scope == 'subject' ? 'Scope: Môn' : 'Scope: Khung',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: widget.scope == 'subject'
                                    ? AppTheme.accentOrange
                                    : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Xóa hội thoại',
                  onPressed: () => provider.clearHistory(),
                ),
              ],
            ),
          ),

          // Server status bar
          const ServerStatusBar(),

          // Messages ListView
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final message = provider.messages[index];
                return ChatBubble(
                  message: message,
                );
              },
            ),
          ),

          // Suggested prompts chips
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            color: AppTheme.slate50,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _defaultSuggestions.map((promptText) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      label: Text(promptText),
                      labelStyle: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppTheme.slate200),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      onPressed: provider.isLoading ? null : () => _handleSend(provider, promptText),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: widget.scope == 'subject'
                          ? 'Hỏi về môn ${widget.scopeId}...'
                          : 'Hỏi về chương trình ${widget.scopeId}...',
                      hintStyle: TextStyle(fontSize: 13, color: AppTheme.slate600.withOpacity(0.7)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: (text) => _handleSend(provider, text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                  onPressed: provider.isLoading
                      ? null
                      : () => _handleSend(provider, _textController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
