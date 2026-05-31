import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'providers/instances_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/lock_gate.dart';

class CoolifyCompanionApp extends ConsumerWidget {
  const CoolifyCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Tint the theme with the active account's accent colour.
    final active = ref.watch(activeInstanceProvider);
    final accent = active == null ? null : Color(active.accentColor);

    return MaterialApp.router(
      title: 'Coolify Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => LockGate(child: child ?? const SizedBox()),
    );
  }
}
