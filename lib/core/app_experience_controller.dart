import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages head-unit experience preferences: projection beta, immersive mode,
/// and climate bar.
class AppExperienceController extends ChangeNotifier {
  AppExperienceController._();

  static final AppExperienceController instance = AppExperienceController._();

  /// Unchanged on purpose. It used to gate CarPlay alone and now gates both
  /// projection stacks, so keeping the key means a user who already turned the
  /// beta on does not find it off after an update.
  static const _projectionKey = 'carplay_beta_enabled';
  static const _immersiveKey = 'app_immersive_mode_enabled';
  static const _statusBarHiddenKey = 'app_status_bar_hidden';
  static const _climateBarKey = 'app_climate_bar_enabled';

  bool _projectionEnabled = false;
  bool _immersiveEnabled = true;
  bool _statusBarHidden = false;
  bool _climateBarEnabled = false;

  /// Whether the projection beta — CarPlay and Android Auto together — is on.
  /// Opt-in: off until the user asks for it.
  bool get projectionEnabled => _projectionEnabled;

  /// Whether the app hides the head unit system bars.
  ///
  /// On by default, because the car screen is small and the app owns it. Off
  /// gives the status and navigation bars back, which the user needs when the
  /// head unit has no other way to leave the app.
  bool get immersiveEnabled => _immersiveEnabled;

  /// Whether the status bar stays hidden while the app is not immersive.
  bool get statusBarHidden => _statusBarHidden;

  /// Whether the shell shows the climate bar along its bottom edge.
  bool get climateBarEnabled => _climateBarEnabled;

  /// Reads the persisted choices.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _projectionEnabled = prefs.getBool(_projectionKey) ?? false;
    _immersiveEnabled = prefs.getBool(_immersiveKey) ?? true;
    _statusBarHidden = prefs.getBool(_statusBarHiddenKey) ?? false;
    _climateBarEnabled = prefs.getBool(_climateBarKey) ?? false;
    notifyListeners();
  }

  /// Turns the projection beta on or off and remembers the choice.
  Future<void> setProjectionEnabled(bool value) async {
    if (_projectionEnabled == value) return;
    _projectionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_projectionKey, value);
  }

  /// Shows or hides the system bars and remembers the choice.
  Future<void> setImmersiveEnabled(bool value) async {
    if (_immersiveEnabled == value) return;
    _immersiveEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_immersiveKey, value);
  }

  /// Hides or shows the status bar of the windowed mode and remembers it.
  Future<void> setStatusBarHidden(bool value) async {
    if (_statusBarHidden == value) return;
    _statusBarHidden = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statusBarHiddenKey, value);
  }

  /// Shows or hides the climate bar and remembers the choice.
  Future<void> setClimateBarEnabled(bool value) async {
    if (_climateBarEnabled == value) return;
    _climateBarEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_climateBarKey, value);
  }

  @visibleForTesting
  Future<void> reset() async {
    _projectionEnabled = false;
    _immersiveEnabled = true;
    _statusBarHidden = false;
    _climateBarEnabled = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_projectionKey);
    await prefs.remove(_immersiveKey);
    await prefs.remove(_statusBarHiddenKey);
    await prefs.remove(_climateBarKey);
  }
}
