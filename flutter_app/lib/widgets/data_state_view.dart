import 'package:flutter/material.dart';

import '../models/load_status.dart';

/// Shared loading/empty/error presentation. State and retry live in the ViewModel.
class DataStateView extends StatelessWidget {
  const DataStateView({
    super.key,
    required this.status,
    this.message,
    this.onRetry,
  });
  final LoadStatus status;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: status == LoadStatus.loading
          ? const CircularProgressIndicator(semanticsLabel: 'Đang tải dữ liệu')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message ??
                        (status == LoadStatus.empty
                            ? 'Chưa có dữ liệu.'
                            : 'Không thể tải dữ liệu.'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ],
            ),
    ),
  );
}
