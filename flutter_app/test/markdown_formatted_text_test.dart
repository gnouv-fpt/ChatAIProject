import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/chat/views/widgets/markdown_formatted_text.dart';

void main() {
  testWidgets('renders short or malformed markdown without RangeError', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MarkdownFormattedText(
            text: '### Kế hoạch học môn\n\n**\n- **Mục tiêu:** luyện bài',
          ),
        ),
      ),
    );

    expect(find.text('Kế hoạch học môn'), findsOneWidget);
    expect(find.textContaining('Mục tiêu'), findsOneWidget);
  });
}
