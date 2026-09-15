import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/quick_prompts_widget.dart';
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

  void _handleSend(ChatProvider provider, String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    provider.sendPrompt(text);
    _scrollToBottom();
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
              'Trợ lý Chat AI FLM',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Xóa lịch sử chat',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xóa lịch sử trò chuyện?'),
                  content: const Text(
                      'Tất cả các tin nhắn hiện tại sẽ được xóa và làm mới.'),
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

          // Chat Messages List
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: provider.messages.isEmpty
                  ? const Center(
                      child: Text('Chưa có tin nhắn nào.'),
                    )
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

          // Quick Prompt Chips (Kịch bản mẫu FLM)
          QuickPromptsWidget(
            onPromptSelected: (prompt) => _handleSend(provider, prompt),
          ),

          const Divider(height: 1),

          // Input Bar Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (text) => _handleSend(provider, text),
                      decoration: InputDecoration(
                        hintText: 'Hỏi về môn học, thi PE, LOs, tín chỉ, HK...',
                        hintStyle: TextStyle(
                            fontSize: 13.5, color: Colors.grey.shade500),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                          : const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: provider.isLoading
                          ? null
                          : () => _handleSend(provider, _textController.text),
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
}
