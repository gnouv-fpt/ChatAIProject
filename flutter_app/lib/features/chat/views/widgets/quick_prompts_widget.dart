import 'package:flutter/material.dart';

class QuickPromptsWidget extends StatelessWidget {
  final Function(String prompt) onPromptSelected;

  const QuickPromptsWidget({super.key, required this.onPromptSelected});

  static const List<Map<String, String>> _samplePrompts = [
    {
      'icon': '📝',
      'label': 'Thi PE PRM392',
      'prompt': 'Môn PRM392 có thi PE (Practical Exam) hay không?',
    },
    {
      'icon': '🎯',
      'label': 'Mục tiêu LOs',
      'prompt': 'Mục tiêu của môn học PRM392 (Learning Outcomes) là gì?',
    },
    {
      'icon': '🔢',
      'label': 'Số tín chỉ',
      'prompt': 'Trong khung chương trình của tôi, môn PRM392 có mấy tín chỉ?',
    },
    {
      'icon': '🗓️',
      'label': 'Kế hoạch học tập',
      'prompt': 'Môn SWD392 học ở học kỳ mấy?',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _samplePrompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _samplePrompts[index];
          return ActionChip(
            avatar: Text(item['icon']!, style: const TextStyle(fontSize: 14)),
            label: Text(
              item['label']!,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.blue.shade200),
            elevation: 1,
            onPressed: () => onPromptSelected(item['prompt']!),
          );
        },
      ),
    );
  }
}
