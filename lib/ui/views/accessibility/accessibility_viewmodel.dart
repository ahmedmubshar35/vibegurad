import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/accessibility_service.dart';

class AccessibilityViewModel extends BaseViewModel {
  final _accessibilityService = locator<AccessibilityService>();

  // Getters
  double get textScaleFactor => _accessibilityService.textScaleFactor;
  bool get highContrastMode => _accessibilityService.highContrastMode;
  bool get reduceAnimations => _accessibilityService.reduceAnimations;
  bool get screenReaderEnabled => _accessibilityService.screenReaderEnabled;
  Map<String, double> get availableTextScales => _accessibilityService.availableTextScales;
  
  String get currentTextScaleName => _accessibilityService.currentTextScaleName;

  // Methods
  Future<void> setTextScale(String scaleName) async {
    setBusy(true);
    try {
      final scaleValue = _accessibilityService.availableTextScales[scaleName] ?? 1.0;
      await _accessibilityService.setTextScaleFactor(scaleValue);
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error setting text scale: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> setHighContrastMode(bool enabled) async {
    setBusy(true);
    try {
      await _accessibilityService.setHighContrastMode(enabled);
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error setting high contrast mode: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> setReduceAnimations(bool enabled) async {
    setBusy(true);
    try {
      await _accessibilityService.setReduceAnimations(enabled);
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error setting reduce animations: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> setScreenReaderEnabled(bool enabled) async {
    setBusy(true);
    try {
      await _accessibilityService.setScreenReaderEnabled(enabled);
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error setting screen reader: $e');
    } finally {
      setBusy(false);
    }
  }
}
