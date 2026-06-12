import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _kDarkMode = 'settings_dark_mode';
  static const _kGpsInterval = 'settings_gps_interval';
  // ignore: unused_field
  static const _kLanguage = 'settings_language'; // reserved for future language support

  final SharedPreferences _prefs;

  bool _darkMode = false;
  int _gpsInterval = 60;
  final String _language = 'ru';

  SettingsProvider(this._prefs) {
    _load();
  }

  bool get darkMode => _darkMode;
  int get gpsInterval => _gpsInterval;
  String get language => _language;

  void _load() {
    _darkMode = _prefs.getBool(_kDarkMode) ?? false;
    _gpsInterval = _prefs.getInt(_kGpsInterval) ?? 60;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs.setBool(_kDarkMode, value);
    notifyListeners();
  }

  Future<void> setGpsInterval(int value) async {
    _gpsInterval = value;
    await _prefs.setInt(_kGpsInterval, value);
    notifyListeners();
  }
}
