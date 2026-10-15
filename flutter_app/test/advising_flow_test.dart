import 'dart:convert';

import 'package:flm_courses/app/app_shell.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/pages/course_detail_page.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineChat extends ChatApiService {
  _OfflineChat() : super(baseUrl: 'http://localhost:8000');
  @override
  Future<bool> checkHealth() async => false;
}

Course _course(String code, int semester, List<String> prerequisites) =>
    Course.fromJson({
      'code': code,
      'name': code,
      'name_vi': code,
      'credits': 3,
      'semester': semester,
      'prerequisites': prerequisites,
      'prerequisites_norm': prerequisites,
      'learning_outcomes': ['CLO: vận dụng kiến thức của $code'],
    });

void main() {
  for (final width in [360.0, 412.0]) {
    testWidgets(
      'confirmed progress leads to next-term prerequisite detail at ${width.toInt()} dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        SharedPreferences.setMockInitialValues({
          'flm_transcript_v1': jsonEncode([
            {
              'courseCode': 'PRF192',
              'score': 8.0,
              'credits': 3,
              'semester': 1,
              'isPassed': true,
              'inProgress': false,
            },
            {
              'courseCode': 'CSI106',
              'score': 0.0,
              'credits': 3,
              'semester': 1,
              'isPassed': false,
              'inProgress': true,
            },
          ]),
        });
        final transcript = TranscriptProvider();
        await transcript.load();
        final profile = LearningProfileProvider();
        await profile.load();
        final catalog = CourseCatalog()
          ..curriculum = Curriculum.fromJson({
            'id': 'TEST',
            'code': 'TEST',
            'name': 'Test',
            'name_vi': 'Chương trình test',
            'total_credits': 12,
            'total_subjects': 4,
          })
          ..courses = [
            _course('PRF192', 1, []),
            _course('CSI106', 1, []),
            _course('PRO192', 2, ['PRF192']),
            _course('BLK201', 2, ['CSI106']),
          ];
        final chat = ChatProvider(apiService: _OfflineChat(), profile: profile);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: catalog),
              ChangeNotifierProvider.value(value: transcript),
              ChangeNotifierProvider.value(value: profile),
              ChangeNotifierProvider.value(value: chat),
            ],
            child: MaterialApp(
              home: const AppShell(),
              onGenerateRoute: (settings) => MaterialPageRoute<void>(
                builder: (_) =>
                    CourseDetailPage(code: settings.name!.split('/').last),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.drag(find.byType(ListView).first, const Offset(0, -400));
        await tester.pump();
        expect(find.text('Học kỳ suy ra từ môn đang học: 1'), findsOneWidget);
        await tester.tap(find.text('Lộ trình'));
        await tester.pump();
        await tester.tap(find.text('Kỳ tới · HK2'));
        await tester.pump();
        expect(
          find.textContaining('Đủ tiên quyết theo dữ liệu đã nhập'),
          findsOneWidget,
        );
        expect(find.textContaining('Còn thiếu: CSI106'), findsOneWidget);
        tester
            .widget<ListTile>(
              find.ancestor(
                of: find.textContaining('PRO192 ·').first,
                matching: find.byType(ListTile),
              ),
            )
            .onTap!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(CourseDetailPage), findsOneWidget);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -650),
        );
        await tester.pump();
        expect(find.text('Chuẩn đầu ra'), findsOneWidget);
        expect(find.text('Điều kiện môn học'), findsOneWidget);
        expect(find.text('Tiêu chí đánh giá'), findsOneWidget);
        await tester.drag(find.byType(TabBar), const Offset(-220, 0));
        await tester.pump();
        await tester.tap(find.text('Điều kiện môn học'));
        await tester.pump();
        expect(find.text('PRF192'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
