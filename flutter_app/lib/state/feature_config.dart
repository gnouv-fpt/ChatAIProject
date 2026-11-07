import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class FeatureConfig extends ChangeNotifier {
  FeatureConfig(this._remoteConfig);

  final FirebaseRemoteConfig _remoteConfig;
  static const previewKey = 'next_course_preview_limit';
  static const tipsKey = 'enable_pe_tips';

  int nextCoursePreviewLimit = 3;
  bool enablePeTips = true;
  bool loading = false;
  String? error;

  Future<void> initialize() async {
    await _remoteConfig.setDefaults(const {previewKey: 3, tipsKey: true});
    _readValues();
    await refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 12),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );
      await _remoteConfig.fetchAndActivate();
      _readValues();
    } catch (_) {
      error = 'Không tải được cấu hình mới; ứng dụng đang dùng giá trị an toàn đã lưu.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _readValues() {
    nextCoursePreviewLimit = _remoteConfig.getInt(previewKey).clamp(1, 10);
    enablePeTips = _remoteConfig.getBool(tipsKey);
  }
}
