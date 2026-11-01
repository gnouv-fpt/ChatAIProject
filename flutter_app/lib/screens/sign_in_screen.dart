import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/m3_components.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final auth = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Cố vấn học tập FLM'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.school_rounded,
                          size: 36,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Đăng nhập để tiếp tục',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hồ sơ học tập, bảng điểm cá nhân và dữ liệu tư vấn AI được bảo mật theo tài khoản của bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (auth.message != null) ...[
                      InlineBanner(
                        message: auth.message!,
                        severity: BannerSeverity.error,
                      ),
                      const SizedBox(height: 20),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Semantics(
                        label: 'Đăng nhập bằng tài khoản Google',
                        button: true,
                        child: FilledButton.icon(
                          onPressed: auth.busy ? null : auth.signIn,
                          icon: auth.busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.login_rounded, size: 20),
                          label: Text(
                            auth.busy ? 'Đang xác thực...' : 'Đăng nhập với Google',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Xác thực an toàn qua Google OAuth 2.0',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
