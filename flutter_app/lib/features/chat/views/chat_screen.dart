import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/grade_import_service.dart';
import '../../../state/course_catalog.dart';
import '../../../state/transcript_provider.dart';
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

  void _showSessions(ChatProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const ListTile(title: Text('Các phiên tư vấn')),
              Expanded(
                child: provider.sessions.isEmpty
                    ? const Center(child: Text('Chưa có phiên tư vấn nào.'))
                    : ListView(
                        children: [
                          for (final session in provider.sessions)
                            ListTile(
                              leading: Icon(session.scope == 'subject'
                                  ? Icons.menu_book_outlined
                                  : Icons.route_outlined),
                              title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${session.category} · ${session.scopeId}'),
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

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
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
    if (provider.isLoading || (text.trim().isEmpty && _images.isEmpty)) return;
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

    // Scroll to bottom whenever new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_outline, size: 22),
            SizedBox(width: 8),
            Text(
              'Cố vấn học tập FLM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Các phiên tư vấn',
            onPressed: () => _showSessions(provider),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Phiên tư vấn mới',
            onPressed: provider.startNewSession,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa lịch sử chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xóa lịch sử trò chuyện?'),
                  content: const Text(
                    'Tất cả các tin nhắn hiện tại sẽ được xóa và làm mới.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        provider.clearHistory();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Server Status Indicator (FastAPI Online / Offline Fallback)
          const ServerStatusBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(provider.currentScope == 'subject'
                  ? 'Phiên môn học · ${provider.currentScopeId}'
                  : 'Phiên tổng quan · ${provider.currentScopeId}'),
            ),
          ),
          if (provider.lastError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Không kết nối được nguồn dữ liệu. Vui lòng thử lại.',
                    ),
                  ),
                  if (provider.canRetryLastFailed)
                    TextButton(
                      onPressed: provider.isLoading
                          ? null
                          : () => provider.retryLastFailed(
                              studentContext: _studentContext(provider),
                            ),
                      child: const Text('Thử lại'),
                    ),
                ],
              ),
            ),

          // Chat Messages List
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: provider.messages.isEmpty
                  ? const Center(child: Text('Chưa có tin nhắn nào.'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: provider.messages.length,
                      itemBuilder: (context, index) {
                        return ChatBubble(message: provider.messages[index]);
                      },
                    ),
            ),
          ),

          const Divider(height: 1),

          // Input Bar Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_images.isNotEmpty)
                    Row(
                      children: [
                        Expanded(child: Text('Đã chọn ${_images.length} ảnh')),
                        TextButton(
                          onPressed: () => setState(_images.clear),
                          child: const Text('Bỏ ảnh'),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Đính kèm ảnh',
                        onPressed: provider.isLoading ? null : _pickImages,
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (text) => _handleSend(provider, text),
                          decoration: InputDecoration(
                            hintText:
                                'Hỏi về môn học, thi PE, LOs, tín chỉ, HK...',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: Colors.grey.shade500,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            fillColor: const Color(0xFFF0F4F8),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: provider.isLoading
                            ? Colors.grey
                            : const Color(0xFF1976D2),
                        child: IconButton(
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: Colors.white,
                                  size: 20,
                                ),
                          onPressed: provider.isLoading
                              ? null
                              : () =>
                                    _handleSend(provider, _textController.text),
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
}
