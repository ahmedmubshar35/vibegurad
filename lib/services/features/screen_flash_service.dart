import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../enums/exposure_level.dart';

@lazySingleton
class ScreenFlashService {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  
  SharedPreferences? _prefs;
  OverlayEntry? _currentFlashOverlay;
  bool _isFlashing = false;

  // Flash patterns for different alert levels
  static const Map<ExposureLevel, FlashPattern> flashPatterns = {
    ExposureLevel.low: FlashPattern(
      color: Colors.green,
      duration: Duration(milliseconds: 500),
      pulses: 1,
      opacity: 0.3,
    ),
    ExposureLevel.medium: FlashPattern(
      color: Colors.orange,
      duration: Duration(milliseconds: 300),
      pulses: 2,
      opacity: 0.5,
    ),
    ExposureLevel.high: FlashPattern(
      color: Colors.red,
      duration: Duration(milliseconds: 200),
      pulses: 3,
      opacity: 0.7,
    ),
    ExposureLevel.critical: FlashPattern(
      color: Colors.red,
      duration: Duration(milliseconds: 100),
      pulses: 5,
      opacity: 0.9,
    ),
  };

  ScreenFlashService();

  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize screen flash service: $e',
      );
    }
  }

  // Flash screen based on exposure level
  Future<void> flashForExposureLevel(ExposureLevel level, BuildContext context) async {
    if (!await isFlashEnabled()) return;
    if (_isFlashing) return; // Prevent overlapping flashes

    final pattern = flashPatterns[level] ?? flashPatterns[ExposureLevel.low]!;
    await _performFlash(pattern, context);
  }

  // Flash with custom pattern
  Future<void> flashWithPattern(FlashPattern pattern, BuildContext context) async {
    if (!await isFlashEnabled()) return;
    if (_isFlashing) return;

    await _performFlash(pattern, context);
  }

  // Warning flash pattern
  Future<void> flashWarning(BuildContext context) async {
    await flashForExposureLevel(ExposureLevel.medium, context);
  }

  // Critical flash pattern
  Future<void> flashCritical(BuildContext context) async {
    await flashForExposureLevel(ExposureLevel.critical, context);
  }

  // Emergency stop flash
  Future<void> flashEmergencyStop(BuildContext context) async {
    if (!await isFlashEnabled()) return;
    if (_isFlashing) return;

    const emergencyPattern = FlashPattern(
      color: Colors.red,
      duration: Duration(milliseconds: 150),
      pulses: 6,
      opacity: 1.0,
    );

    await _performFlash(emergencyPattern, context);
  }

  // Rest break reminder flash
  Future<void> flashRestReminder(BuildContext context) async {
    if (!await isFlashEnabled()) return;
    if (_isFlashing) return;

    const restPattern = FlashPattern(
      color: Colors.blue,
      duration: Duration(milliseconds: 400),
      pulses: 2,
      opacity: 0.4,
    );

    await _performFlash(restPattern, context);
  }

  // Perform the actual flash animation
  Future<void> _performFlash(FlashPattern pattern, BuildContext context) async {
    if (_isFlashing) return;

    try {
      _isFlashing = true;

      // Add haptic feedback for accessibility
      await HapticFeedback.lightImpact();

      final overlay = Overlay.of(context);
      // Check if overlay context is still mounted

      for (int i = 0; i < pattern.pulses; i++) {
        // Create flash overlay
        _currentFlashOverlay = OverlayEntry(
          builder: (context) => FlashOverlayWidget(
            color: pattern.color,
            opacity: pattern.opacity,
            duration: pattern.duration,
          ),
        );

        // Insert overlay
        overlay.insert(_currentFlashOverlay!);

        // Wait for flash duration
        await Future.delayed(pattern.duration);

        // Remove overlay
        _currentFlashOverlay?.remove();
        _currentFlashOverlay = null;

        // Brief pause between pulses (except for last pulse)
        if (i < pattern.pulses - 1) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Screen flash error: $e',
      );
    } finally {
      _isFlashing = false;
    }
  }

  // Stop current flash
  void stopFlash() {
    _currentFlashOverlay?.remove();
    _currentFlashOverlay = null;
    _isFlashing = false;
  }

  // Settings management
  Future<void> setFlashEnabled(bool enabled) async {
    await _prefs?.setBool('screen_flash_enabled', enabled);
  }

  Future<bool> isFlashEnabled() async {
    return _prefs?.getBool('screen_flash_enabled') ?? true;
  }

  Future<void> setFlashIntensity(double intensity) async {
    final clampedIntensity = intensity.clamp(0.1, 1.0);
    await _prefs?.setDouble('flash_intensity', clampedIntensity);
  }

  Future<double> getFlashIntensity() async {
    return _prefs?.getDouble('flash_intensity') ?? 0.7;
  }

  Future<void> setAccessibilityMode(bool enabled) async {
    await _prefs?.setBool('flash_accessibility_mode', enabled);
  }

  Future<bool> isAccessibilityModeEnabled() async {
    return _prefs?.getBool('flash_accessibility_mode') ?? false;
  }

  // Test flash functionality
  Future<void> testFlash(BuildContext context, ExposureLevel level) async {
    try {
      await flashForExposureLevel(level, context);
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to test flash: $e',
      );
    }
  }

  // Dispose service
  void dispose() {
    stopFlash();
  }
}

// Flash pattern model
class FlashPattern {
  final Color color;
  final Duration duration;
  final int pulses;
  final double opacity;

  const FlashPattern({
    required this.color,
    required this.duration,
    required this.pulses,
    required this.opacity,
  });

  FlashPattern copyWith({
    Color? color,
    Duration? duration,
    int? pulses,
    double? opacity,
  }) {
    return FlashPattern(
      color: color ?? this.color,
      duration: duration ?? this.duration,
      pulses: pulses ?? this.pulses,
      opacity: opacity ?? this.opacity,
    );
  }
}

// Flash overlay widget
class FlashOverlayWidget extends StatefulWidget {
  final Color color;
  final double opacity;
  final Duration duration;

  const FlashOverlayWidget({
    Key? key,
    required this.color,
    required this.opacity,
    required this.duration,
  }) : super(key: key);

  @override
  State<FlashOverlayWidget> createState() => _FlashOverlayWidgetState();
}

class _FlashOverlayWidgetState extends State<FlashOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.opacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward().then((_) {
      _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return IgnorePointer(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: widget.color.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// Screen flash settings model
class ScreenFlashSettings {
  final bool enabled;
  final double intensity;
  final bool accessibilityMode;
  final Map<ExposureLevel, FlashPattern> customPatterns;

  ScreenFlashSettings({
    required this.enabled,
    required this.intensity,
    required this.accessibilityMode,
    required this.customPatterns,
  });

  factory ScreenFlashSettings.defaults() {
    return ScreenFlashSettings(
      enabled: true,
      intensity: 0.7,
      accessibilityMode: false,
      customPatterns: Map.from(ScreenFlashService.flashPatterns),
    );
  }

  ScreenFlashSettings copyWith({
    bool? enabled,
    double? intensity,
    bool? accessibilityMode,
    Map<ExposureLevel, FlashPattern>? customPatterns,
  }) {
    return ScreenFlashSettings(
      enabled: enabled ?? this.enabled,
      intensity: intensity ?? this.intensity,
      accessibilityMode: accessibilityMode ?? this.accessibilityMode,
      customPatterns: customPatterns ?? this.customPatterns,
    );
  }
}