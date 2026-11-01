import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../services/grade_import_service.dart';
import '../../../state/course_catalog.dart';
import '../../../state/transcript_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/server_status_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<ImageFile> _images = [];

  final List<String> _quickPrompts = const [
    'Tôi nên học gì ở kỳ tới?',
    'Điều kiện tiên quyết của SEP490?',
    'Làm sao để cải thiện GPA an toàn?',
    'Quy định về hạ bậc tốt nghiệp?',
  ];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  String _sessionTime(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  void _showSessions(ChatProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const ListTile(
                title: Text(
                  'Các phiên tư vấn',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: provider.sessions.isEmpty
                    ? const Center(child: Text('Chưa có phiên tư vấn nào.'))
                    : ListView(
                        children: [
                          for (final session in provider.sessions)
                            ListTile(
                              leading: Icon(
                                session.scope == 'subject'
                                    ? Icons.menu_book_outlined
                                    : Icons.route_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(
                                session.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${session.contextLabel} · ${session.category}\n${_sessionTime(session.lastActivity)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              isThreeLine: true,
                              onTap: () {
                                provider.openSession(session.id);
                                Navigator.pop(sheetContext);
                              },
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory(ChatProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa toàn bộ cuộc trò chuyện?'),
        content: const Text(
          'Tất cả các tin nhắn trong hội thoại hiện tại sẽ bị xóa khỏi thiết bị. Bạn sẽ không thể khôi phục lại các tin nhắn này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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

  Future<void> _pickImages() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || selected == null) return;
    if (_images.length + selected.files.length > 10 ||
        selected.files.any(
          (file) => file.bytes == null || file.bytes!.isEmpty,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chọn tối đa 10 ảnh PNG hoặc JPG hợp lệ.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      for (final file in selected.files) {
        _images.add(
          ImageFile(
            filename: file.name,
            bytes: file.bytes!,
            mimeType: file.extension?.toLowerCase() == 'png'
                ? 'image/png'
                : 'image/jpeg',
          ),
        );
      }
    });
  }

  void _handleSend(ChatProvider provider, String text) {
    if (!provider.historyAvailable ||
        provider.isLoading ||
        (text.trim().isEmpty && _images.isEmpty)) {
      return;
    }
    final images = List<ImageFile>.from(_images);
    _textController.clear();
    setState(_images.clear);
    if (images.isEmpty) {
      provider.sendPrompt(text, studentContext: _studentContext(provider));
    } else {
      provider.sendPromptWithImages(
        text.trim().isEmpty
            ? 'Hãy đọc và phân tích ảnh này theo ngữ cảnh hiện tại.'
            : text,
        images,
      );
    }
    _scrollToBottom();
  }

  Map<String, dynamic> _studentContext(ChatProvider provider) {
    final transcript = context.read<TranscriptProvider>();
    final catalog = context.read<CourseCatalog>();
    final remaining = transcript.hasTranscript
        ? (catalog.totalCreditsInGpa - transcript.evaluation.totalGpaCredits)
              .clamp(0, catalog.totalCreditsInGpa)
        : catalog.totalCreditsInGpa;
    return transcript.buildStudentContextFacts(
      remainingGpaCredits: remaining,
      subjectCode: provider.currentScope == 'subject'
          ? provider.currentScopeId
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canSend = !provider.isLoading &&
        (_textController.text.trim().isNotEmpty || _images.isNotEmpty);
    final hasUserMessage = provider.messages.any((m) => m.sender == ChatSender.user);

    // Scroll to bottom whenever new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      bottomSheet: provider.historyError == null
          ? null
          : Material(
              child: SafeArea(
                child: ListTile(
                  title: Text(provider.historyError!),
                  trailing: TextButton(
                    onPressed: provider.retryHistorySync,
                    child: const Text('Thử lại'),
                  ),
                ),
              ),
            ),
      appBar: FlmAppBar(
        title: 'Trợ lý AI FLM',
        subtitle: 'Tư vấn môn học & chiến lược GPA',
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử phiên tư vấn',
            onPressed: () => _showSessions(provider),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn hội thoại',
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            onSelected: (value) {
              if (value == 'new_session') {
                provider.startNewSession();
              } else if (value == 'clear_history') {
                _confirmClearHistory(provider);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_session',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Cuộc trò chuyện mới'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
                    SizedBox(width: 10),
                    Text('Xóa hội thoại', style: TextStyle(color: AppTheme.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Slim Offline / Connecting Banner (hidden when online)
          const ServerStatusBar(),

          // 2. Active Scope Indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusPill(
                label: provider.currentScope == 'subject'
                    ? 'Phiên môn học · ${provider.currentScopeId}'
                    : 'Phiên tổng quan · ${provider.currentScopeId}',
                icon: provider.currentScope == 'subject'
                    ? Icons.menu_book_rounded
                    : Icons.school_rounded,
                color: colorScheme.primary,
                background: colorScheme.primaryContainer.withValues(alpha: 0.5),
              ),
            ),
          ),

          // 3. Error retry row (if last failed)
          if (provider.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Không thể kết nối đến máy chủ. Hãy thử lại.',
                      style: TextStyle(fontSize: 12.5, color: colorScheme.error),
                    ),
                  ),
                  if (provider.canRetryLastFailed)
                    TextButton.icon(
                      onPressed: provider.isLoading
                          ? null
                          : () => provider.retryLastFailed(
                              studentContext: _studentContext(provider),
                            ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Thử lại'),
                    ),
                ],
              ),
            ),

          // 4. Chat Messages List OR Friendly Empty State with 4 prompt chips
          Expanded(
            child: !hasUserMessage
                ? _buildEmptyState(context, provider)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = provider.messages[index];
                      return ChatBubble(
                        message: msg,
                        onRetry: provider.canRetryLastFailed
                            ? () => provider.retryLastFailed(
                                studentContext: _studentContext(provider),
                              )
                            : null,
                      );
                    },
                  ),
          ),

          const Divider(height: 1),

          // 5. Input Bar Section (multi-line up to 5, disabled button when empty, keyboard safe)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: colorScheme.surface,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.image_outlined, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Đã chọn ${_images.length} ảnh đính kèm',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(_images.clear),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Bỏ chọn'),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Đính kèm ảnh',
                        onPressed: provider.isLoading ? null : _pickImages,
                        icon: const Icon(Icons.attach_file_rounded),
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
                              hintText: 'Hỏi về môn học, tiên quyết, GPA...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chào bạn! Tôi có thể giúp gì?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hỏi về lộ trình môn học, điều kiện tiên quyết hoặc chiến lược điểm GPA.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final prompt in _quickPrompts)
                  ActionChip(
                    avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: Text(prompt),
                    labelStyle: TextStyle(
                      fontSize: 13,
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
