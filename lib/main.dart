import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Background/terminated message handler — must be a top-level function.
/// Notification messages are shown by the OS automatically; this is here for
/// completeness (and data-only messages).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional — the app still runs if it isn't configured for the
  // current platform (e.g. iOS without GoogleService-Info.plist).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}
  runApp(const ProviderScope(child: CoolifyCompanionApp()));
}
