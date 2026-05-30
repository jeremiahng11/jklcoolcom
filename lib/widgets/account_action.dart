import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/instances_provider.dart';
import '../screens/instance_switcher.dart';

/// App-bar leading button showing the active account's accent avatar; tapping
/// opens the account switcher.
class AccountAction extends ConsumerWidget {
  const AccountAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeInstanceProvider);
    final color = active == null ? Colors.grey : Color(active.accentColor);
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showInstanceSwitcher(context),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: color,
          child: Text(
            (active?.label.isNotEmpty ?? false)
                ? active!.label[0].toUpperCase()
                : '?',
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
