import 'package:flutter/material.dart';

/// Widget parse và hiển thị nội dung tin nhắn Markdown AI một cách trực quan,
/// hiện đại và tối ưu UX (chia card môn học, highlight tiêu đề, format thẻ số liệu).
class MarkdownFormattedText extends StatelessWidget {
  final String text;
  final bool isUser;

  const MarkdownFormattedText({
    super.key,
    required this.text,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return SelectableText(
        text,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final lines = text.split('\n');
    final List<Widget> widgets = [];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      // 1. Tiêu đề lớn: ###, ##, #
      if (line.startsWith('### ') || line.startsWith('## ') || line.startsWith('# ')) {
        final title = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 2. Nhận diện dòng thẻ Môn học: "- **CODE**: Tên môn (X tín chỉ)" hoặc "• **CODE**: ..."
      final courseMatch = RegExp(r'^[-*•]\s*\*\*([A-Z]{3}\d{3}[a-z]?)\*\*:\s*(.*?)(?:\s*\((.*?)\))?$').firstMatch(line);
      if (courseMatch != null) {
        final code = courseMatch.group(1) ?? '';
        final name = courseMatch.group(2) ?? '';
        final creditsInfo = courseMatch.group(3) ?? '';

        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                ),
                if (creditsInfo.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      creditsInfo,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 3. Nhận diện cảnh báo hoặc lưu ý hạ bậc
      if (line.contains('Cảnh báo') || line.contains('hạ bậc') || line.contains('học lại từ 2 môn')) {
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildRichText(line, defaultColor: const Color(0xFF92400E)),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. Nhận diện các đầu mục thứ tự: **1. ...**, **2. ...**
      if (RegExp(r'^\*{0,2}\d+\.\s+').hasMatch(line)) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: _buildRichText(
              line,
              defaultColor: const Color(0xFF0F172A),
              fontSize: 14.0,
              baseBold: true,
            ),
          ),
        );
        i++;
        continue;
      }

      // 5. Gạch đầu dòng thông thường: - ..., * ..., • ...
      if (line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ')) {
        final content = line.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 5, color: Color(0xFF64748B)),
                ),
                Expanded(
                  child: _buildRichText(content, defaultColor: const Color(0xFF334155)),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 6. Dòng text thông thường
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildRichText(line, defaultColor: const Color(0xFF334155)),
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Phân tích cú pháp inline Markdown: **in đậm**, *in nghiêng*, `code`
  Widget _buildRichText(
    String line, {
    Color defaultColor = const Color(0xFF334155),
    double fontSize = 13.5,
    bool baseBold = false,
  }) {
    final List<InlineSpan> spans = [];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|`.*?`)');
    int lastEnd = 0;

    for (final match in regex.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: line.substring(lastEnd, match.start),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontWeight: baseBold ? FontWeight.w700 : FontWeight.w400,
              color: defaultColor,
            ),
          ),
        );
      }

      final matchedText = match.group(0)!;
      // A single italic pattern can also match the two asterisks in `**`.
      // Only strip delimiters when there is actually content between them.
      final isBold = matchedText.length >= 4 &&
          matchedText.startsWith('**') &&
          matchedText.endsWith('**');
      final isItalic = matchedText.length >= 3 &&
          matchedText.startsWith('*') &&
          matchedText.endsWith('*') &&
          !matchedText.startsWith('**');
      final isCode = matchedText.length >= 2 &&
          matchedText.startsWith('`') &&
          matchedText.endsWith('`');

      if (isBold) {
        spans.add(
          TextSpan(
            text: matchedText.substring(2, matchedText.length - 2),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: defaultColor == const Color(0xFF92400E)
                  ? const Color(0xFF78350F)
                  : const Color(0xFF0F172A),
            ),
          ),
        );
      } else if (isItalic) {
        spans.add(
          TextSpan(
            text: matchedText.substring(1, matchedText.length - 1),
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: defaultColor,
            ),
          ),
        );
      } else if (isCode) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                matchedText.substring(1, matchedText.length - 1),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      } else {
        // Keep malformed Markdown visible instead of attempting an invalid slice.
        spans.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(
              fontSize: fontSize,
              height: 1.45,
              fontWeight: baseBold ? FontWeight.w700 : FontWeight.w400,
              color: defaultColor,
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(lastEnd),
          style: TextStyle(
            fontSize: fontSize,
            height: 1.45,
            fontWeight: baseBold ? FontWeight.w700 : FontWeight.w400,
            color: defaultColor,
          ),
        ),
      );
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
