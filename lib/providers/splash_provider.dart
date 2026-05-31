import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the launch splash has finished (started fading out). Other gates
/// (e.g. the biometric lock) wait on this so their prompts don't appear over
/// the splash.
class SplashDoneNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void complete() {
    if (!state) state = true;
  }
}

final splashDoneProvider = NotifierProvider<SplashDoneNotifier, bool>(
  SplashDoneNotifier.new,
);
