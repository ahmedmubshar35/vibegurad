import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stacked/stacked.dart';

@lazySingleton
class LocalizationService with ListenableServiceMixin {
  static const String _localeKey = 'selected_locale';
  
  Locale _currentLocale = const Locale('en');
  SharedPreferences? _prefs;

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('es'), // Spanish  
    Locale('fr'), // French
  ];

  // Language display names
  static const Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
  };

  Locale get currentLocale => _currentLocale;
  String get currentLanguageCode => _currentLocale.languageCode;
  String get currentLanguageName => languageNames[currentLanguageCode] ?? 'English';

  List<Locale> get availableLocales => supportedLocales;
  
  Map<String, String> get availableLanguages => languageNames;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadLocaleFromPreferences();
  }

  Future<void> _loadLocaleFromPreferences() async {
    final savedLanguageCode = _prefs?.getString(_localeKey) ?? 'en';
    
    // Validate that the saved locale is supported
    final savedLocale = Locale(savedLanguageCode);
    if (supportedLocales.contains(savedLocale)) {
      _currentLocale = savedLocale;
    } else {
      _currentLocale = const Locale('en'); // Default to English
    }
    
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;
    
    if (supportedLocales.contains(locale)) {
      _currentLocale = locale;
      await _prefs?.setString(_localeKey, locale.languageCode);
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    final locale = Locale(languageCode);
    await setLocale(locale);
  }

  Future<void> setToEnglish() => setLanguage('en');
  Future<void> setToSpanish() => setLanguage('es');
  Future<void> setToFrench() => setLanguage('fr');

  // Get display name for a language code
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode.toUpperCase();
  }

  // Check if a locale is supported
  bool isLocaleSupported(Locale locale) {
    return supportedLocales.any((supportedLocale) => 
        supportedLocale.languageCode == locale.languageCode);
  }

  // Get locale from system settings  
  Locale localeResolutionCallback(List<Locale>? locales, Iterable<Locale> supportedLocales) {
    if (locales != null) {
      for (final locale in locales) {
        if (isLocaleSupported(locale)) {
          return locale;
        }
      }
    }
    return const Locale('en'); // Default fallback
  }
}