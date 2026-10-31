import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(title: const Text('Cố vấn học tập FLM')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IconTile(
                      icon: Icons.school_outlined,
                      color: AppTheme.primaryBlue,
                      background: AppTheme.primaryLight,
                      size: 64,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Đăng nhập để tiếp tục',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hồ sơ và bảng điểm được tách riêng theo tài khoản.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (auth.message != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warningSurface,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            auth.message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: Semantics(
                        label: 'Đăng nhập bằng tài khoản Google',
                        child: FilledButton.icon(
                          onPressed: auth.busy ? null : auth.signIn,
                          icon: auth.busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text('Đăng nhập với Google'),
                        ),
                      ),
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
