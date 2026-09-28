import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider();

  ThemeMode _themeMode = ThemeMode.system;
  bool _wifiOnly = false;
  bool _autoSave = true;
  bool _adsEnabled = true;
  String _downloadDirectory = 'Movies/TokSave';

  ThemeMode get themeMode => _themeMode;
  bool get wifiOnly => _wifiOnly;
  bool get autoSave => _autoSave;
  bool get adsEnabled => _adsEnabled;
  String get downloadDirectory => _downloadDirectory;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('themeMode') ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => ThemeMode.system,
    );
    _wifiOnly = prefs.getBool('wifiOnly') ?? false;
    _autoSave = prefs.getBool('autoSave') ?? true;
    _adsEnabled = prefs.getBool('adsEnabled') ?? true;
    _downloadDirectory = prefs.getString('downloadDirectory') ?? 'Movies/TokSave';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifiOnly', value);
    notifyListeners();
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSave', value);
    notifyListeners();
  }

  Future<void> setAdsEnabled(bool value) async {
    _adsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adsEnabled', value);
    notifyListeners();
  }

  Future<void> setDownloadDirectory(String value) async {
    _downloadDirectory = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('downloadDirectory', value);
    notifyListeners();
  }
}
