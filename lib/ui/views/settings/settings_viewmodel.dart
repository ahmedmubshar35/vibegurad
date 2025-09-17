import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/authentication_service.dart';
import '../../../services/core/theme_service.dart';
import '../../../services/core/localization_service.dart';
import '../../../models/core/user.dart';
import 'widgets/account_management.dart';

class SettingsViewModel extends ReactiveViewModel {
  final _authService = locator<AuthenticationService>();
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();
  final _themeService = locator<ThemeService>();
  final _localizationService = locator<LocalizationService>();

  @override
  List<ListenableServiceMixin> get listenableServices => [_themeService, _localizationService];

  SettingsViewModel() {
    print("✅ SettingsViewModel created - Theme: ${_themeService.currentThemeName}, Language: ${_localizationService.currentLanguageName}");
  }

  User? get currentUser => _authService.currentUser;

  // Notification Settings
  bool _allowNotifications = true;
  bool _safetyAlerts = true;
  bool _breakReminders = true;
  bool _dailyReports = false;

  bool get allowNotifications => _allowNotifications;
  bool get safetyAlerts => _safetyAlerts;
  bool get breakReminders => _breakReminders;
  bool get dailyReports => _dailyReports;

  // Safety Settings
  int _dailyExposureLimit = 360; // minutes (6 hours)
  int _warningThreshold = 80; // percentage
  int _breakInterval = 60; // minutes

  int get dailyExposureLimit => _dailyExposureLimit;
  int get warningThreshold => _warningThreshold;
  int get breakInterval => _breakInterval;

  // Theme Settings
  ThemeMode get themeMode => _themeService.themeMode;
  bool get isDarkMode => _themeService.isDarkMode;
  bool get isLightMode => _themeService.isLightMode;
  bool get isSystemMode => _themeService.isSystemMode;
  String get currentThemeName => _themeService.currentThemeName;
  IconData get currentThemeIcon => _themeService.currentThemeIcon;
  
  // Language Settings
  String get currentLanguage => _localizationService.currentLanguageName;
  String get currentLanguageCode => _localizationService.currentLanguageCode;
  Map<String, String> get availableLanguages => _localizationService.availableLanguages;

  void toggleNotifications(bool value) {
    _allowNotifications = value;
    notifyListeners();
    _saveSettings();
  }

  void toggleSafetyAlerts(bool value) {
    _safetyAlerts = value;
    notifyListeners();
    _saveSettings();
  }

  void toggleBreakReminders(bool value) {
    _breakReminders = value;
    notifyListeners();
    _saveSettings();
  }

  void toggleDailyReports(bool value) {
    _dailyReports = value;
    notifyListeners();
    _saveSettings();
  }

  void setDailyExposureLimit(int minutes) {
    _dailyExposureLimit = minutes;
    notifyListeners();
    _saveSettings();
  }

  void setWarningThreshold(int percentage) {
    _warningThreshold = percentage;
    notifyListeners();
    _saveSettings();
  }

  void setBreakInterval(int minutes) {
    _breakInterval = minutes;
    notifyListeners();
    _saveSettings();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _themeService.setThemeMode(themeMode);
    _saveSettings();
  }

  Future<void> toggleTheme() async {
    await _themeService.toggleTheme();
    _saveSettings();
  }

  Future<void> setLightMode() => setThemeMode(ThemeMode.light);
  Future<void> setDarkMode() => setThemeMode(ThemeMode.dark);
  Future<void> setSystemMode() => setThemeMode(ThemeMode.system);

  Future<void> setLanguage(String languageCode) async {
    await _localizationService.setLanguage(languageCode);
    _saveSettings();
  }

  Future<void> setToEnglish() => setLanguage('en');
  Future<void> setToSpanish() => setLanguage('es');
  Future<void> setToFrench() => setLanguage('fr');

  Future<void> _saveSettings() async {
    // In a real app, you'd save to SharedPreferences or Firebase
    await Future.delayed(Duration(milliseconds: 500));
    _snackbarService.showSnackbar(message: 'Settings saved');
  }

  Future<void> resetToDefaults() async {
    setBusy(true);
    
    _allowNotifications = true;
    _safetyAlerts = true;
    _breakReminders = true;
    _dailyReports = false;
    _dailyExposureLimit = 360;
    _warningThreshold = 80;
    _breakInterval = 60;
    await _themeService.setThemeMode(ThemeMode.system);
    await _localizationService.setLanguage('en');
    
    await Future.delayed(Duration(seconds: 1));
    setBusy(false);
    notifyListeners();
    _snackbarService.showSnackbar(message: 'Settings reset to defaults');
  }

  Future<void> exportSettings() async {
    setBusy(true);
    
    // Simulate export
    await Future.delayed(Duration(seconds: 2));
    
    setBusy(false);
    _snackbarService.showSnackbar(message: 'Settings exported successfully');
  }

  Future<void> importSettings() async {
    setBusy(true);
    
    // Simulate import
    await Future.delayed(Duration(seconds: 2));
    
    setBusy(false);
    _snackbarService.showSnackbar(message: 'Settings imported successfully');
  }

  Future<void> clearCache() async {
    setBusy(true);
    
    // Simulate cache clearing
    await Future.delayed(Duration(seconds: 1));
    
    setBusy(false);
    _snackbarService.showSnackbar(message: 'Cache cleared successfully');
  }

  Future<void> signOut() async {
    setBusy(true);
    
    try {
      await _authService.signOut();
      _navigationService.clearStackAndShow('/login');
    } catch (e) {
      _snackbarService.showSnackbar(message: 'Error signing out: $e');
    } finally {
      setBusy(false);
    }
  }

  void navigateToProfile() {
    _navigationService.navigateTo('/profile');
  }
  
  void navigateToAccountManagement() {
    Navigator.push(
      StackedService.navigatorKey!.currentContext!,
      MaterialPageRoute(
        builder: (context) => const AccountManagementView(),
      ),
    );
  }

  void showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About Vibe Guard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Vibe Guard helps construction workers monitor their exposure to hand-arm vibration, preventing HAVS and ensuring workplace safety.'),
            SizedBox(height: 16),
            Text('© 2024 Vibe Guard. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
