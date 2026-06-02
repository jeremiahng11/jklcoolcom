import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Root navigator key, shared by the router and by code that needs to navigate
/// from outside the widget tree (e.g. a tapped local notification).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Navigate to [location] in response to a notification tap. No-op if the app
/// isn't ready (e.g. tapped while terminated — handled at startup instead).
void navigateFromNotification(String location) {
  final context = rootNavigatorKey.currentContext;
  if (context != null) context.push(location);
}
