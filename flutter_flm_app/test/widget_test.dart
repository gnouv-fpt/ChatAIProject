import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_flm_app/main.dart';

void main() {
  testWidgets('FlmObsidianApp renders ChatScreen successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FlmObsidianApp());

    // Verify that ChatScreen elements are rendered
    expect(find.text('Trợ lý Chat AI FLM'), findsOneWidget);
    expect(find.text('Thi PE PRM392'), findsOneWidget);
    expect(find.text('Mục tiêu LOs'), findsOneWidget);
  });
}
