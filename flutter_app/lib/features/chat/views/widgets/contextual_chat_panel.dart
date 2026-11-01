import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../services/grade_import_service.dart';
import '../../../../state/course_catalog.dart';
import '../../../../state/transcript_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/curriculum_formatters.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import 'chat_bubble.dart';
import 'server_status_bar.dart';

class ContextualChatPanel extends StatefulWidget {
  final String scope; // 'curriculum' | 'subject'
  final String scopeId; // e.g. 'BIT_SE_K19B' or 'PRM393'
  final String? backendScopeId;
  final String? contextHint;
  final String title;
  final String? subtitle;
  final int? semesterNumber;
  final List<String>? suggestedQuestions;
  final VoidCallback? onClose;

  const ContextualChatPanel({
    super.key,
    required this.scope,
    required this.scopeId,
    this.backendScopeId,
    this.contextHint,
    required this.title,
    this.subtitle,
    this.semesterNumber,
    this.suggestedQuestions,
    this.onClose,
  });

  @override
  State<ContextualChatPanel> createState() => _ContextualChatPanelState();
}

class _ContextualChatPanelState extends State<ContextualChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isPickingImages = false;
  bool _showContextDetails = false;
  final List<ImageFile> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatProvider>().updateScope(
        scope: widget.scope,
        id: widget.scopeId,
      );
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ContextualChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.scopeId != widget.scopeId ||
        oldWidget.semesterNumber != widget.semesterNumber) {
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
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        if (MediaQuery.disableAnimationsOf(context)) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          return;
        }
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSend(ChatProvider provider, String text) {
    if (!provider.historyAvailable ||
        provider.isLoading ||
        (text.trim().isEmpty && _pendingImages.isEmpty)) {
      return;
    }
    _textController.clear();

    final tp = context.read<TranscriptProvider>();
    final catalog = context.read<CourseCatalog>();
    final remaining = tp.hasTranscript
        ? (catalog.totalCreditsInGpa - tp.evaluation.totalGpaCredits).clamp(
            0,
            catalog.totalCreditsInGpa,
          )
        : catalog.totalCreditsInGpa;
    final facts = tp.buildStudentContextFacts(
      remainingGpaCredits: remaining,
      subjectCode: widget.scope == 'subject' ? widget.scopeId : null,
      semesterNumber: widget.scope == 'curriculum'
          ? widget.semesterNumber
          : null,
    );
    final studentContext = facts.isEmpty ? null : facts;

    if (_pendingImages.isNotEmpty) {
      final images = List<ImageFile>.from(_pendingImages);
      setState(() => _pendingImages.clear());
      provider.sendPromptWithImages(
        text.trim().isEmpty ? 'Hãy phân tích ảnh đính kèm theo ngữ cảnh.' : text,
        images,
        scope: widget.scope,
        id: widget.scopeId,
        backendId: widget.backendScopeId,
        contextHint: widget.contextHint,
        studentContext: studentContext,
      );
      _scrollToBottom();
      return;
    }

    provider.sendPrompt(
      text,
      scope: widget.scope,
      id: widget.scopeId,
      backendId: widget.backendScopeId,
      contextHint: widget.contextHint,
      studentContext: studentContext,
    );
    _scrollToBottom();
  }

  Future<void> _pickImages() async {
    if (_isPickingImages) return;
    setState(() => _isPickingImages = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final images = result.files
          .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
          .take(10)
          .map(
            (file) => ImageFile(
              filename: file.name,
              bytes: file.bytes!,
              mimeType: file.extension?.toLowerCase() == 'png'
                  ? 'image/png'
                  : 'image/jpeg',
            ),
          )
          .toList();
      if (images.isEmpty) throw Exception('Không đọc được ảnh đã chọn.');
      if (!mounted) return;
      setState(() => _pendingImages.addAll(images));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chọn ảnh thất bại: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  List<String> get _defaultSuggestions {
    if (widget.suggestedQuestions != null &&
        widget.suggestedQuestions!.isNotEmpty) {
      return widget.suggestedQuestions!;
    }
    if (widget.scope == 'subject') {
      final cleanCode = widget.scopeId.contains(':')
          ? widget.scopeId.split(':').last
          : widget.scopeId;
      return [
        'Môn $cleanCode có thi PE không?',
        'Mục tiêu môn học (LOs) của $cleanCode là gì?',
        'Tư vấn cách học môn $cleanCode hiệu quả?',
        'Môn $cleanCode có tính vào điểm GPA không?',
      ];
    }
    if (widget.semesterNumber != null) {
      final sem = widget.semesterNumber!;
      return [
        'Học kỳ $sem có những môn nào?',
        'Môn nào nặng nhất trong học kỳ $sem?',
        'Tôi nên chuẩn bị gì trước cho học kỳ $sem?',
        'Lưu ý về tiên quyết các môn ở học kỳ $sem?',
      ];
    }
    final lowerTitle = widget.title.toLowerCase();
    final lowerScope = widget.scopeId.toLowerCase();
    if (lowerTitle.contains('bảng điểm') || lowerScope.contains('transcript')) {
      return const [
        'Tiến độ tích lũy tín chỉ hiện tại của tôi?',
        'Môn nào tôi đã hoàn thành và môn nào còn nợ?',
        'Dự báo GPA và chiến lược cải thiện điểm?',
        'Khung chương trình có bao nhiêu tín chỉ?',
      ];
    }
    return const [
      'Khung chương trình có bao nhiêu tín chỉ?',
      'Các môn tiên quyết quan trọng nhất là gì?',
      'Tôi nên đăng ký môn theo lộ trình thế nào?',
      'Quy định về hạ bậc tốt nghiệp như thế nào?',
    ];
  }

  String get _formattedTitle {
    final raw = widget.title.trim();
    if (raw.toLowerCase().startsWith('học kỳ')) {
      return 'Học kỳ ${widget.semesterNumber ?? raw.replaceAll(RegExp(r'[^0-9]'), '')}'.trim();
    }
    if (raw.toLowerCase() == 'trang chủ') {
      return 'Tổng quan chương trình';
    }
    if (widget.scope == 'subject') {
      final cleanCode = widget.scopeId.contains(':')
          ? widget.scopeId.split(':').last
          : widget.scopeId;
      return 'Trợ lý môn $cleanCode';
    }
    // Sentence case (capital letter only at start)
    return capitalizeFirst(raw);
  }

  Future<void> _confirmClear(ChatProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa hội thoại này?'),
        content: const Text(
          'Các tin nhắn trong hội thoại hiện tại sẽ bị xóa. Bạn không thể hoàn tác thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      provider.clearHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSend = !provider.isLoading &&
        (_textController.text.trim().isNotEmpty || _pendingImages.isNotEmpty);
    final hasUserMessage = provider.messages.any((m) => m.sender == ChatSender.user);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompactHeight = screenHeight < 450;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // 1. Drag Handle (hidden on short landscape viewports)
          if (!isCompactHeight)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // 2. Header of Chat Panel
          Padding(
            padding: EdgeInsets.fromLTRB(16, isCompactHeight ? 2 : 4, 8, isCompactHeight ? 2 : 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formattedTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.subtitle ??
                            widget.contextHint ??
                            formatContextScopeLabel(
                              scope: widget.scope,
                              scopeId: widget.scopeId,
                              title: widget.title,
                              semesterNumber: widget.semesterNumber,
                            ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  tooltip: 'Tùy chọn',
                  onSelected: (value) {
                    if (value == 'new_session') {
                      provider.startNewSession();
                    } else if (value == 'clear_history') {
                      _confirmClear(provider);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'new_session',
                      child: Row(
                        children: [
                          Icon(Icons.add_comment_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Phiên mới'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_history',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Xóa hội thoại',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Đóng Trợ lý AI',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // 3. Clickable Context Chip (hidden on compact landscape viewports)
          if (!isCompactHeight)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: Icon(
                    widget.scope == 'subject' ? Icons.menu_book_rounded : Icons.school_rounded,
                    size: 15,
                    color: colorScheme.primary,
                  ),
                  label: Text(
                    formatContextScopeLabel(
                      scope: widget.scope,
                      scopeId: widget.scopeId,
                      title: widget.title,
                      semesterNumber: widget.semesterNumber,
                    ),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                  backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onPressed: () => setState(() => _showContextDetails = !_showContextDetails),
                ),
              ),
            ),

          // Inline context details panel
          if (_showContextDetails)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.contextHint ??
                            'Ngữ cảnh: $_formattedTitle',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showContextDetails = false),
                      borderRadius: BorderRadius.circular(99),
                      child: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Server Status Bar (hidden when online)
          const ServerStatusBar(),

          if (provider.historyError != null)
            ListTile(
              title: Text(
                provider.historyError!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: TextButton(
                onPressed: provider.retryHistorySync,
                child: const Text('Thử lại'),
              ),
            ),

          // 5. Messages ListView OR Empty State
          Expanded(
            child: !hasUserMessage
                ? _buildEmptyState(context, provider)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final message = provider.messages[index];
                      return ChatBubble(
                        message: message,
                        onRetry: provider.canRetryLastFailed
                            ? () => provider.retryLastFailed()
                            : null,
                      );
                    },
                  ),
          ),

          // 6. Pending images preview
          if (_pendingImages.isNotEmpty)
            Container(
              height: 72,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = _pendingImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          image.bytes,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filled(
                          tooltip: 'Bỏ ảnh',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          onPressed: () => setState(() => _pendingImages.removeAt(index)),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black87,
                          ),
                          icon: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // 7. Horizontal Suggestion Chips (when user has already sent messages)
          if (hasUserMessage)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _defaultSuggestions.map((promptText) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(promptText),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                        backgroundColor: colorScheme.surface,
                        side: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        onPressed: provider.isLoading ? null : () => _handleSend(provider, promptText),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // 8. Input Bar (Multi-line up to 5, disabled button when empty, keyboard safe)
          Container(
            padding: EdgeInsets.fromLTRB(12, isCompactHeight ? 4 : 8, 12, isCompactHeight ? 4 : 10),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: MediaQuery.viewInsetsOf(context).bottom == 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Đính kèm ảnh',
                    onPressed: provider.isLoading || _isPickingImages ? null : _pickImages,
                    icon: _isPickingImages
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  Expanded(
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.enter &&
                            !HardwareKeyboard.instance.isShiftPressed) {
                          if (_textController.value.isComposingRangeValid) {
                            return KeyEventResult.ignored;
                          }
                          _handleSend(provider, _textController.text);
                          return KeyEventResult.handled;
                        }
                        return KeyEventResult.ignored;
                      },
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: widget.contextHint != null
                              ? 'Hỏi về ${widget.title}...'
                              : 'Hỏi về môn học, tiên quyết...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            borderSide: BorderSide(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: IconButton.filled(
                      tooltip: provider.isLoading ? 'Dừng' : 'Gửi câu hỏi',
                      style: IconButton.styleFrom(
                        backgroundColor: provider.isLoading
                            ? colorScheme.error
                            : (canSend ? colorScheme.primary : colorScheme.surfaceContainerHighest),
                        foregroundColor: provider.isLoading
                            ? colorScheme.onError
                            : (canSend ? colorScheme.onPrimary : colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      ),
                      icon: provider.isLoading
                          ? const Icon(Icons.stop_rounded, size: 20)
                          : const Icon(Icons.send_rounded, size: 20),
                      onPressed: provider.isLoading
                          ? () => provider.cancelCurrentRequest()
                          : (canSend ? () => _handleSend(provider, _textController.text) : null),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChatProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_rounded, color: colorScheme.primary, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Hỏi về $_formattedTitle',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn một câu hỏi gợi ý bên dưới hoặc tự nhập câu hỏi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final prompt in _defaultSuggestions.take(4))
                  ActionChip(
                    avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                    label: Text(prompt),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                    backgroundColor: colorScheme.surfaceContainerLow,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    onPressed: () => _handleSend(provider, prompt),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
