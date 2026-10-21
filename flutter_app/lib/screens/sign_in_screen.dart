import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_view_model.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cố vấn học tập FLM')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Đăng nhập để tiếp tục',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hồ sơ và bảng điểm được tách riêng theo tài khoản.',
                ),
                const SizedBox(height: 24),
                if (auth.message != null) ...[
                  Semantics(liveRegion: true, child: Text(auth.message!)),
                  const SizedBox(height: 16),
                ],
                Semantics(
                  label: 'Đăng nhập bằng tài khoản Google',
                  child: FilledButton.icon(
                    onPressed: auth.busy ? null : auth.signIn,
                    icon: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Đăng nhập với Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
