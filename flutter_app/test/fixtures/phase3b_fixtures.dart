import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flm_courses/features/chat/providers/chat_provider.dart';
import 'package:flm_courses/features/chat/services/chat_api_service.dart';
import 'package:flm_courses/models/course.dart';
import 'package:flm_courses/models/curriculum.dart';
import 'package:flm_courses/services/auth_service.dart';
import 'package:flm_courses/services/grade_import_service.dart';
import 'package:flm_courses/services/transcript_image_picker.dart';
import 'package:flm_courses/state/auth_view_model.dart';
import 'package:flm_courses/state/course_catalog.dart';
import 'package:flm_courses/state/learning_profile_provider.dart';
import 'package:flm_courses/state/transcript_import_view_model.dart';
import 'package:flm_courses/state/transcript_provider.dart';
import 'package:flm_courses/theme/app_theme.dart';
import 'package:provider/provider.dart';

class MockChatApiService extends ChatApiService {
  MockChatApiService({
    this.isOnline = true,
    this.responseResult,
    this.completer,
  }) : super(baseUrl: 'http://localhost:8000');

  final bool isOnline;
  ChatResponseResult? responseResult;
  Completer<ChatResponseResult>? completer;

  @override
  Future<bool> checkHealth() async => isOnline;

  @override
  Future<ChatResponseResult> sendMessage(
    String prompt, {
    String? scope,
    String? id,
    String? courseCode,
    Map<String, dynamic>? studentContext,
    List<Map<String, String>> history = const [],
  }) async {
    if (completer != null) {
      return completer!.future;
    }
    return responseResult ??
        ChatResponseResult(
          answer: 'Đây là câu trả lời thử nghiệm từ Cố vấn AI.',
          sources: const ['FLM Syllabus 2026'],
          isOfflineFallback: false,
        );
  }
}

class TestAuthService implements AuthService {
  TestAuthService({this.userName = 'Nguyễn Đăng Khôi', this.signedIn = true});
  final String userName;
  final bool signedIn;

  @override
  Stream<AuthAccount?> get changes => Stream.value(
        signedIn ? AuthAccount(uid: 'khoind', name: userName) : null,
      );

  @override
  Future<void> signIn() async {}

  @override
  Future<void> signOut() async {}
}

class MockImagePicker implements TranscriptImagePicker {
  @override
  Future<List<ImageFile>?> pick() async => null;
}

CourseCatalog createTestCatalog() {
  return CourseCatalog()
    ..curriculum = Curriculum.fromJson({
      'id': 'BIT_SE_K19B',
      'code': 'BIT_SE_K19B',
      'name': 'Software Engineering',
      'name_vi': 'Kỹ thuật phần mềm',
      'total_credits': 147,
      'total_subjects': 48,
    })
    ..courses = [
      Course.fromJson({
        'code': 'PRF192',
        'name': 'Programming Fundamentals',
        'name_vi': 'Cơ sở lập trình',
        'credits': 3,
        'semester': 1,
      }),
      Course.fromJson({
        'code': 'PRM393',
        'name': 'Mobile Programming',
        'name_vi': 'Lập trình di động',
        'credits': 3,
        'semester': 5,
        'prerequisites': ['PRO192'],
      }),
    ];
}

Widget wrapWithChatProviders({
  required Widget child,
  required ChatProvider chat,
  CourseCatalog? catalog,
  LearningProfileProvider? profile,
  TranscriptProvider? transcript,
  AuthViewModel? auth,
  bool isDark = false,
  double textScale = 1.0,
  Size viewport = const Size(390, 844),
  EdgeInsets viewInsets = EdgeInsets.zero,
  Key? repaintKey,
}) {
  final effectiveCatalog = catalog ?? createTestCatalog();
  final effectiveProfile = profile ?? LearningProfileProvider();
  final effectiveTranscript = transcript ?? TranscriptProvider();
  final effectiveAuth = auth ?? AuthViewModel(TestAuthService());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: effectiveCatalog),
      ChangeNotifierProvider.value(value: effectiveProfile),
      ChangeNotifierProvider.value(value: effectiveTranscript),
      ChangeNotifierProvider.value(value: effectiveAuth),
      ChangeNotifierProvider.value(value: chat),
      Provider<TranscriptImagePicker>(create: (_) => MockImagePicker()),
      ChangeNotifierProvider(
        create: (context) => TranscriptImportViewModel(
          picker: context.read<TranscriptImagePicker>(),
          service: () => GradeImportService(baseUrl: chat.baseUrl),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          viewInsets: viewInsets,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: SizedBox(
          width: viewport.width,
          height: viewport.height,
          child: repaintKey != null
              ? RepaintBoundary(key: repaintKey, child: child)
              : child,
        ),
      ),
    ),
  );
}
