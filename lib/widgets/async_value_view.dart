import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import 'empty_state.dart';

/// Renders an [AsyncValue]: spinner while loading, a friendly error state with
/// retry on failure, and [data] on success.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingLabel,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: true,
      data: data,
      loading: () => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (loadingLabel != null) ...[
              const SizedBox(height: 16),
              Text(loadingLabel!),
            ],
          ],
        ),
      ),
      error: (err, _) {
        final message = err is ApiException
            ? err.message
            : 'Something went wrong.\n$err';
        final isScope = err is ApiException && err.isScopeError;
        return EmptyState(
          icon: isScope ? Icons.lock_outline : Icons.error_outline,
          title: isScope ? 'Permission denied' : 'Could not load',
          message: message,
          action: onRetry == null
              ? null
              : FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
        );
      },
    );
  }
}
