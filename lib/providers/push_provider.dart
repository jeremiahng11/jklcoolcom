import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../navigation.dart';
import 'notifications_provider.dart';

class PushState {
  const PushState({this.enabled = false, this.token, this.available = true});

  /// User toggled notifications on.
  final bool enabled;

  /// The device's FCM registration token (for testing / backend delivery).
  final String? token;

  /// Whether FCM is available on this build/device (false when Firebase isn't
  /// configured, e.g. iOS without GoogleService-Info.plist).
  final bool available;

  PushState copyWith({bool? enabled, String? token, bool? available}) =>
      PushState(
        enabled: enabled ?? this.enabled,
        token: token ?? this.token,
        available: available ?? this.available,
      );
}

/// Manages push-notification opt-in: requests permission, fetches the FCM
/// token, and shows incoming messages as local notifications while the app is
/// in the foreground.
class PushNotifier extends Notifier<PushState> {
  static const _key = 'push_enabled';
  static const _channelId = 'default_channel';

  final _local = FlutterLocalNotificationsPlugin();
  bool _listening = false;

  @override
  PushState build() {
    _load();
    return const PushState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? false;
    if (enabled) {
      final ok = await _setup();
      state = state.copyWith(enabled: ok);
    }
  }

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    const channel = AndroidNotificationChannel(
      _channelId,
      'Notifications',
      description: 'Coolify Companion alerts',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    // Foreground messages: record in the inbox and show a local notification.
    FirebaseMessaging.onMessage.listen((message) {
      _record(message);
      final n = message.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    });
    // Notification tapped while the app was backgrounded.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _record(message);
      _navigate(message);
    });
  }

  /// Store a received message in the in-app inbox.
  void _record(RemoteMessage m) {
    final n = m.notification;
    final data = m.data;
    final id = m.messageId ?? '${DateTime.now().microsecondsSinceEpoch}';
    ref
        .read(notificationsProvider.notifier)
        .add(
          AppNotification(
            id: id,
            title: n?.title ?? data['title']?.toString() ?? 'Notification',
            body: n?.body ?? data['body']?.toString() ?? '',
            route: AppNotification.routeFromData(data),
            time: DateTime.now(),
            read: false,
          ),
        );
  }

  /// Deep-link to the screen the notification points at, if any.
  void _navigate(RemoteMessage m) {
    final route = AppNotification.routeFromData(m.data);
    if (route != null) navigateFromNotification(route);
  }

  /// Requests permission, sets up listeners and fetches the token. Returns true
  /// on success.
  Future<bool> _setup() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      await _initLocal();
      _listen();
      final token = await messaging.getToken();
      state = state.copyWith(token: token);
      messaging.onTokenRefresh.listen((t) => state = state.copyWith(token: t));
      // App launched from terminated by tapping a notification.
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _record(initial);
        Future.delayed(
          const Duration(milliseconds: 600),
          () => _navigate(initial),
        );
      }
      return true;
    } catch (_) {
      state = state.copyWith(available: false);
      return false;
    }
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final ok = await _setup();
      if (!ok) {
        await prefs.setBool(_key, false);
        state = state.copyWith(enabled: false);
        return;
      }
    }
    await prefs.setBool(_key, value);
    state = state.copyWith(enabled: value);
  }
}

final pushProvider = NotifierProvider<PushNotifier, PushState>(
  PushNotifier.new,
);
