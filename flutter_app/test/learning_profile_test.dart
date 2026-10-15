import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/screens/settings_screen.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'learning preferences persist and are sent without transcript',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final first = LearningProfileProvider();
      await first.load();
      expect(first.chatContext, isEmpty);

      await first.update(
        courseGoal: 'high_score',
        learningStyle: 'practice',
        studyPriority: 'depth',
        longTermGoal: 'study_abroad',
        currentSemester: 4,
        careerGoal: 'Lập trình viên mobile',
      );
      final reopened = LearningProfileProvider();
      await reopened.load();
      expect(reopened.chatContext, {
        'course_goal': 'high_score',
        'learning_style': 'practice',
        'study_priority': 'depth',
        'long_term_goal': 'study_abroad',
        'current_semester': 4,
        'career_goal': 'Lập trình viên mobile',
      });

      await reopened.update(courseGoal: 'pass');
      final changed = LearningProfileProvider();
      await changed.load();
      expect(changed.chatContext, {'course_goal': 'pass'});
    },
  );

  testWidgets('reopened settings shows saved choices', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final saved = LearningProfileProvider();
    await saved.update(
      courseGoal: 'high_score',
      learningStyle: 'reading',
      studyPriority: 'time',
      longTermGoal: 'career',
      currentSemester: 3,
    );
    final reopened = LearningProfileProvider();
    await reopened.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: reopened),
          ChangeNotifierProvider(create: (_) => TranscriptProvider()),
          ChangeNotifierProvider(create: (_) => CourseCatalog()),
          ChangeNotifierProvider(
            create: (_) => ChatProvider(profile: reopened),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    expect(find.text('Đạt điểm cao'), findsOneWidget);
    expect(find.text('Đọc và tóm tắt'), findsOneWidget);
    expect(find.text('Tập trung phần quan trọng trước'), findsOneWidget);
    expect(find.text('Chuẩn bị nghề nghiệp'), findsOneWidget);
    expect(find.text('Học kỳ 3'), findsOneWidget);
  });
}
