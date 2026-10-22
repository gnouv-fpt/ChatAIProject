import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/providers/chat_provider.dart';
import '../state/course_catalog.dart';
import '../state/transcript_provider.dart';
import '../state/learning_profile_provider.dart';
import '../state/auth_view_model.dart';
import '../models/load_status.dart';
import '../widgets/data_state_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverController;
  late final TextEditingController _careerController;
  bool _profileHydrated = false;
  String? _courseGoal;
  String? _learningStyle;
  String? _studyPriority;
  String? _longTermGoal;
  int? _currentSemester;

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController(
      text: context.read<ChatProvider>().baseUrl,
    );
    final profile = context.read<LearningProfileProvider>();
    _courseGoal = profile.courseGoal;
    _learningStyle = profile.learningStyle;
    _studyPriority = profile.studyPriority;
    _longTermGoal = profile.longTermGoal;
    _currentSemester = profile.currentSemester;
    _careerController = TextEditingController(text: profile.careerGoal ?? '');
    _profileHydrated = profile.isLoaded;
  }

  @override
  void dispose() {
    _serverController.dispose();
    _careerController.dispose();
    super.dispose();
  }

  Future<void> _clearTranscript() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bảng điểm?'),
        content: Text(
          context.read<TranscriptProvider>().usesCloud
              ? 'Bảng điểm của tài khoản trên Firestore sẽ bị xóa.'
              : 'Dữ liệu bảng điểm đã lưu trên thiết bị sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<TranscriptProvider>().clearTranscript();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã xóa bảng điểm.')));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa bảng điểm. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel?>();
    final profile = context.watch<LearningProfileProvider>();
    if (profile.status == LoadStatus.loading ||
        profile.status == LoadStatus.error) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cài đặt'),
          actions: [
            if (auth != null)
              TextButton.icon(
                onPressed: auth.busy ? null : auth.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Đăng xuất'),
              ),
          ],
        ),
        body: DataStateView(
          status: profile.status,
          message: profile.error,
          onRetry: profile.status == LoadStatus.error
              ? () => profile.load(retry: true)
              : null,
        ),
      );
    }
    if (!_profileHydrated && profile.isLoaded) {
      _courseGoal = profile.courseGoal;
      _learningStyle = profile.learningStyle;
      _studyPriority = profile.studyPriority;
      _longTermGoal = profile.longTermGoal;
      _currentSemester = profile.currentSemester;
      _careerController.text = profile.careerGoal ?? '';
      _profileHydrated = true;
    }
    final transcript = context.watch<TranscriptProvider>();
    final chat = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (context.read<AuthViewModel?>() case final auth?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.account?.name ?? 'Tài khoản Google'),
                    Text(
                      profile.usesCloud
                          ? 'Hồ sơ và bảng điểm lưu trên Firestore theo tài khoản.'
                          : 'Bộ nhớ cá nhân tách theo tài khoản; chưa bật đồng bộ cloud.',
                    ),
                    if (auth.message != null) Text(auth.message!),
                    OutlinedButton.icon(
                      onPressed: auth.busy ? null : auth.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            'Mục tiêu học tập',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPA mục tiêu: ${transcript.targetGpa.toStringAsFixed(1)}',
                  ),
                  if (transcript.saveError != null) Text(transcript.saveError!),
                  Slider(
                    value: transcript.targetGpa,
                    min: 0,
                    max: 10,
                    divisions: 100,
                    label: transcript.targetGpa.toStringAsFixed(1),
                    onChanged: transcript.setTargetGpa,
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hồ sơ tư vấn (có thể bổ sung dần)'),
                  if (profile.error != null) Text(profile.error!),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _currentSemester,
                    decoration: const InputDecoration(
                      labelText: 'Học kỳ hiện tại (tự xác nhận)',
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('Chưa xác định'),
                      ),
                      for (var semester = 0; semester <= 12; semester++)
                        DropdownMenuItem(
                          value: semester,
                          child: Text('Học kỳ $semester'),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _currentSemester = value),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _courseGoal,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu môn học',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pass', child: Text('Qua môn')),
                      DropdownMenuItem(
                        value: 'high_score',
                        child: Text('Đạt điểm cao'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _courseGoal = value),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _learningStyle,
                    decoration: const InputDecoration(
                      labelText: 'Cách học ưu tiên',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'practice',
                        child: Text('Làm bài thực hành'),
                      ),
                      DropdownMenuItem(
                        value: 'reading',
                        child: Text('Đọc và tóm tắt'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _learningStyle = value),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _studyPriority,
                    decoration: const InputDecoration(
                      labelText: 'Ưu tiên học tập',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'time',
                        child: Text('Tập trung phần quan trọng trước'),
                      ),
                      DropdownMenuItem(
                        value: 'depth',
                        child: Text('Hiểu sâu và làm sản phẩm'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _studyPriority = value),
                  ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _longTermGoal,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu dài hạn',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'graduate',
                        child: Text('Hoàn thành chương trình'),
                      ),
                      DropdownMenuItem(
                        value: 'career',
                        child: Text('Chuẩn bị nghề nghiệp'),
                      ),
                      DropdownMenuItem(
                        value: 'study_abroad',
                        child: Text('Chuẩn bị du học'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _longTermGoal = value),
                  ),
                  TextField(
                    controller: _careerController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu nghề nghiệp (tùy chọn)',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: profile.saving
                          ? null
                          : () async {
                              try {
                                await profile.update(
                                  courseGoal: _courseGoal,
                                  learningStyle: _learningStyle,
                                  studyPriority: _studyPriority,
                                  longTermGoal: _longTermGoal,
                                  currentSemester: _currentSemester,
                                  careerGoal: _careerController.text,
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profile.usesCloud
                                          ? 'Đã lưu hồ sơ lên Firestore.'
                                          : 'Đã lưu hồ sơ tư vấn trên thiết bị.',
                                    ),
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      profile.error ?? 'Không thể lưu hồ sơ. Vui lòng thử lại.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: const Text('Lưu hồ sơ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kết nối trợ lý AI',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _serverController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ API',
                      hintText: 'http://localhost:8000',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final uri = Uri.tryParse(
                              _serverController.text.trim(),
                            );
                            if (uri == null ||
                                !uri.hasAuthority ||
                                (uri.scheme != 'http' &&
                                    uri.scheme != 'https')) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Nhập địa chỉ API hợp lệ.'),
                                ),
                              );
                              return;
                            }
                            chat.updateBaseUrl(
                              _serverController.text.trim().replaceAll(
                                RegExp(r'/$'),
                                '',
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã áp dụng địa chỉ API cho phiên này.',
                                ),
                              ),
                            );
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: chat.checkServerHealth,
                          child: const Text('Thử kết nối'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.isServerOnline == null
                        ? 'Đang kiểm tra kết nối...'
                        : chat.isServerOnline!
                        ? 'Máy chủ đang hoạt động'
                        : 'Không kết nối được. Dữ liệu môn học vẫn dùng được.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Dữ liệu', style: Theme.of(context).textTheme.titleLarge),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Tải lại dữ liệu môn học'),
                  onTap: context.read<CourseCatalog>().load,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Xóa bảng điểm trên thiết bị'),
                  onTap: transcript.hasTranscript ? _clearTranscript : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
