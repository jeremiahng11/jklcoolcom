import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'app.dart';
import 'services/monitor.dart';

/// Background task entry point — must be a top-level function. Runs the monitor
/// poll in its own isolate (best-effort, OS-scheduled).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await runMonitorCheck();
    } catch (_) {}
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (_) {}
  runApp(const ProviderScope(child: CoolifyCompanionApp()));
}
