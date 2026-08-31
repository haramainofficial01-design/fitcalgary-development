import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class OnboardingStore {
  Future<bool> isComplete();
  Future<void> markComplete();
}

class SharedPreferencesOnboardingStore implements OnboardingStore {
  static const key = 'fitcalgary.onboarding.complete.v1';

  @override
  Future<bool> isComplete() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(key) ?? false;
  }

  @override
  Future<void> markComplete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(key, true);
  }
}

class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({bool complete = false}) {
    _complete = complete;
  }

  late bool _complete;
  bool get completed => _complete;

  @override
  Future<bool> isComplete() async => _complete;

  @override
  Future<void> markComplete() async => _complete = true;
}

class OnboardingController extends ChangeNotifier {
  OnboardingController(this.store, {required bool complete}) {
    _complete = complete;
  }

  final OnboardingStore store;
  late bool _complete;
  bool get complete => _complete;

  Future<void> finish() async {
    if (_complete) return;
    await store.markComplete();
    _complete = true;
    notifyListeners();
  }
}
