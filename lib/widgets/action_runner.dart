import 'package:flutter/material.dart';

import '../api/api_exception.dart';

/// Runs an async API action with a blocking overlay, then shows a success or
/// error snackbar. Returns true on success.
Future<bool> runAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String success,
  String? running,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final errorColor = Theme.of(context).colorScheme.error;
  final overlay = _showOverlay(context, running);
  var ok = false;
  String message = success;
  try {
    await action();
    ok = true;
  } on ApiException catch (e) {
    message = e.message;
  } catch (e) {
    message = 'Failed: $e';
  } finally {
    overlay.remove();
  }

  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: ok ? null : errorColor),
  );
  return ok;
}

OverlayEntry _showOverlay(BuildContext context, String? label) {
  final entry = OverlayEntry(
    builder: (_) => ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (label != null) ...[const SizedBox(height: 16), Text(label)],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  return entry;
}

/// Shows a confirmation dialog. Returns true if the user confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
