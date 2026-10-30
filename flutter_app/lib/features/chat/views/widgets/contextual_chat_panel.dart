import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../../../services/grade_import_service.dart';
import '../../../../state/course_catalog.dart';
import '../../../../state/transcript_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import 'chat_bubble.dart';
import 'server_status_bar.dart';

class ContextualChatPanel extends StatefulWidget {
  final String scope; // 'curriculum' | 'subject'
  final String scopeId; // e.g. 'BIT_SE_K19B' or 'PRM393'
  final String title;
  final String? subtitle;
  final int? semesterNumber;
  final List<String>? suggestedQuestions;
  final VoidCallback? onClose;

  const ContextualChatPanel({
    super.key,
    required this.scope,
    required this.scopeId,
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
  final List<ImageFile> _pendingImages = [];

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
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(ChatProvider provider, String text) {
    if (!provider.historyAvailable ||
        provider.isLoading ||
        text.trim().isEmpty) {
      return;
    }
    _textController.clear();

    if (_pendingImages.isNotEmpty) {
      final images = List<ImageFile>.from(_pendingImages);
      setState(() => _pendingImages.clear());
      provider.sendPromptWithImages(
        text,
        images,
        scope: widget.scope,
        id: widget.scopeId,
      );
      _scrollToBottom();
      return;
    }

    // Lấy dữ kiện học tập đã tính bằng code từ TranscriptProvider (Mục 7.4)
    // Nếu chưa có bảng điểm, studentContext = {} và chat vẫn hoạt động bình thường
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

    provider.sendPrompt(
      text,
      scope: widget.scope,
      id: widget.scopeId,
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
        type: FileType.image,
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
              mimeType: _mimeTypeFor(file.extension),
            ),
          )
          .toList();
      if (images.isEmpty) throw Exception('Không đọc được ảnh đã chọn.');
      if (!mounted) return;
      setState(() => _pendingImages.addAll(images));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Chọn ảnh thất bại: $error')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
    }
  }

  static String _mimeTypeFor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  List<String> get _defaultSuggestions {
    if (widget.suggestedQuestions != null &&
        widget.suggestedQuestions!.isNotEmpty) {
      return widget.suggestedQuestions!;
    }
    if (widget.scope == 'subject') {
      return [
        'Môn ${widget.scopeId} có thi PE không?',
        'Mục tiêu môn học (LOs) là gì?',
        'Tư vấn cách học môn này theo mục tiêu của tôi?',
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

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
              border: Border(
                bottom: BorderSide(color: AppTheme.slate200, width: 1),
              ),
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
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.scope == 'subject'
                            ? 'Theo môn học'
                            : 'Theo chương trình',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.slate600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Xóa hội thoại',
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Xóa hội thoại này?'),
                              content: const Text(
                                'Các tin nhắn trong hội thoại hiện tại sẽ bị xóa. Bạn không thể hoàn tác thao tác này.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Xóa hội thoại'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && mounted) {
                            provider.clearHistory();
                          }
                        },
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppTheme.slate600,
                    ),
                    tooltip: 'Đóng Trợ lý AI',
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Server status bar
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

          // Messages ListView
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              itemCount: provider.messages.length,
              itemBuilder: (context, index) {
                final message = provider.messages[index];
                return ChatBubble(message: message);
              },
            ),
          ),

          // Suggested prompts chips
          if (_pendingImages.isNotEmpty)
            Container(
              height: 76,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              color: AppTheme.slate50,
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
                          width: 62,
                          height: 62,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: IconButton.filled(
                          tooltip: 'Bỏ ảnh ${index + 1}',
                          onPressed: () =>
                              setState(() => _pendingImages.removeAt(index)),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black87,
                          ),
                          icon: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (!keyboardVisible)
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
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        label: Text(promptText),
                        labelStyle: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: AppTheme.primaryBlue),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.slate200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        onPressed: provider.isLoading
                            ? null
                            : () => _handleSend(provider, promptText),
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
              border: Border(
                top: BorderSide(color: AppTheme.slate200, width: 1),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Đính kèm ảnh vào câu hỏi',
                  onPressed: provider.isLoading || _isPickingImages
                      ? null
                      : _pickImages,
                  icon: _isPickingImages
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                  color: AppTheme.primaryBlue,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      labelText: 'Câu hỏi của bạn',
                      hintText: widget.scope == 'subject'
                          ? 'Hỏi về môn ${widget.scopeId}...'
                          : 'Hỏi về chương trình ${widget.scopeId}...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.slate600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: const BoxConstraints(minHeight: 48),
                    ),
                    onSubmitted: (text) => _handleSend(provider, text),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: provider.isLoading ? 'Đang trả lời' : 'Gửi câu hỏi',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
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
