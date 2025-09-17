import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stacked/stacked.dart';

@lazySingleton
class AccessibilityService with ListenableServiceMixin {
  static const String _textScaleKey = 'text_scale_factor';
  static const String _highContrastKey = 'high_contrast_mode';
  static const String _reduceAnimationsKey = 'reduce_animations';
  static const String _screenReaderKey = 'screen_reader_enabled';
  
  SharedPreferences? _prefs;
  
  double _textScaleFactor = 1.0;
  bool _highContrastMode = false;
  bool _reduceAnimations = false;
  bool _screenReaderEnabled = false;

  // Text scale options
  static const Map<String, double> textScaleOptions = {
    'Small': 0.85,
    'Normal': 1.0,
    'Large': 1.15,
    'Extra Large': 1.3,
    'Huge': 1.5,
  };

  // Getters
  double get textScaleFactor => _textScaleFactor;
  bool get highContrastMode => _highContrastMode;
  bool get reduceAnimations => _reduceAnimations;
  bool get screenReaderEnabled => _screenReaderEnabled;

  Map<String, double> get availableTextScales => textScaleOptions;
  
  String get currentTextScaleName {
    // Find the closest match to current scale factor
    String closest = 'Normal';
    double closestDiff = double.infinity;
    
    for (final entry in textScaleOptions.entries) {
      final diff = (entry.value - _textScaleFactor).abs();
      if (diff < closestDiff) {
        closestDiff = diff;
        closest = entry.key;
      }
    }
    return closest;
  }

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
    
    // Check system accessibility settings
    _checkSystemAccessibility();
  }

  Future<void> _loadPreferences() async {
    _textScaleFactor = _prefs?.getDouble(_textScaleKey) ?? 1.0;
    _highContrastMode = _prefs?.getBool(_highContrastKey) ?? false;
    _reduceAnimations = _prefs?.getBool(_reduceAnimationsKey) ?? false;
    _screenReaderEnabled = _prefs?.getBool(_screenReaderKey) ?? false;
    
    notifyListeners();
  }

  void _checkSystemAccessibility() {
    // Check for system-level accessibility features
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final mediaQuery = MediaQueryData.fromView(view);
    
    // Auto-enable features based on system settings
    if (mediaQuery.accessibleNavigation) {
      _screenReaderEnabled = true;
    }
    
    if (mediaQuery.disableAnimations) {
      _reduceAnimations = true;
    }
    
    // Update text scale based on system setting  
    final systemTextScaler = mediaQuery.textScaler;
    final systemTextScale = systemTextScaler.scale(16) / 16; // Get scale factor for 16px baseline
    if (systemTextScale != 1.0) {
      _textScaleFactor = systemTextScale;
    }
    
    notifyListeners();
  }

  Future<void> setTextScaleFactor(double factor) async {
    if (_textScaleFactor == factor) return;
    
    _textScaleFactor = factor.clamp(0.5, 2.0);
    await _prefs?.setDouble(_textScaleKey, _textScaleFactor);
    notifyListeners();
    
    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }

  Future<void> setTextScaleByName(String scaleName) async {
    final factor = textScaleOptions[scaleName];
    if (factor != null) {
      await setTextScaleFactor(factor);
    }
  }

  Future<void> setHighContrastMode(bool enabled) async {
    if (_highContrastMode == enabled) return;
    
    _highContrastMode = enabled;
    await _prefs?.setBool(_highContrastKey, enabled);
    notifyListeners();
    
    // Announce change to screen readers
    if (_screenReaderEnabled) {
      SemanticsService.announce(
        enabled ? 'High contrast mode enabled' : 'High contrast mode disabled',
        TextDirection.ltr,
      );
    }
  }

  Future<void> setReduceAnimations(bool enabled) async {
    if (_reduceAnimations == enabled) return;
    
    _reduceAnimations = enabled;
    await _prefs?.setBool(_reduceAnimationsKey, enabled);
    notifyListeners();
    
    if (_screenReaderEnabled) {
      SemanticsService.announce(
        enabled ? 'Animations reduced' : 'Animations restored',
        TextDirection.ltr,
      );
    }
  }

  Future<void> setScreenReaderEnabled(bool enabled) async {
    if (_screenReaderEnabled == enabled) return;
    
    _screenReaderEnabled = enabled;
    await _prefs?.setBool(_screenReaderKey, enabled);
    notifyListeners();
  }

  // Animation duration helper - returns reduced duration if animations are disabled
  Duration getAnimationDuration(Duration normalDuration) {
    if (_reduceAnimations) {
      return Duration(milliseconds: (normalDuration.inMilliseconds * 0.3).round());
    }
    return normalDuration;
  }

  // Helper to create accessible buttons with proper semantics
  Widget createAccessibleButton({
    required Widget child,
    required VoidCallback? onPressed,
    required String semanticLabel,
    String? semanticHint,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      excludeSemantics: excludeSemantics,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    );
  }

  // Helper for accessible text with proper scaling
  Widget createAccessibleText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    String? semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel ?? text,
      child: Text(
        text,
        style: style?.copyWith(
          fontSize: (style.fontSize ?? 16) * _textScaleFactor,
        ) ?? TextStyle(fontSize: 16 * _textScaleFactor),
        textAlign: textAlign,
        textScaler: TextScaler.noScaling, // We handle scaling manually
      ),
    );
  }

  // Helper for focus management
  void requestFocus(FocusNode focusNode) {
    focusNode.requestFocus();
    
    // Provide additional feedback for screen reader users
    if (_screenReaderEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  // Announce important messages to screen readers
  void announceToScreenReader(String message) {
    if (_screenReaderEnabled) {
      SemanticsService.announce(message, TextDirection.ltr);
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _textScaleFactor = 1.0;
    _highContrastMode = false;
    _reduceAnimations = false;
    _screenReaderEnabled = false;
    
    if (_prefs != null) {
      await _prefs!.setDouble(_textScaleKey, _textScaleFactor);
      await _prefs!.setBool(_highContrastKey, _highContrastMode);
      await _prefs!.setBool(_reduceAnimationsKey, _reduceAnimations);
      await _prefs!.setBool(_screenReaderKey, _screenReaderEnabled);
    }
    
    notifyListeners();
    announceToScreenReader('Accessibility settings reset to defaults');
  }

  // Color helpers for high contrast mode
  Color getTextColor(BuildContext context) {
    if (_highContrastMode) {
      return Theme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black;
    }
    return Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  }

  Color getBackgroundColor(BuildContext context) {
    if (_highContrastMode) {
      return Theme.of(context).brightness == Brightness.dark 
          ? Colors.black 
          : Colors.white;
    }
    return Theme.of(context).scaffoldBackgroundColor;
  }

  Color getContrastColor(BuildContext context, Color originalColor) {
    if (_highContrastMode) {
      // Increase contrast by making colors more extreme
      final luminance = originalColor.computeLuminance();
      return luminance > 0.5 ? Colors.black : Colors.white;
    }
    return originalColor;
  }
}