import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF0D47A1);
  
  // Secondary Colors
  static const Color secondary = Color(0xFF26A69A);
  static const Color secondaryLight = Color(0xFF64D8CB);
  static const Color secondaryDark = Color(0xFF00766C);
  
  // Safety Colors
  static const Color safe = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color critical = Color(0xFFD32F2F);
  
  // Neutral Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0E0E0);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFF9E9E9E);
  
  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color info = Color(0xFF2196F3);
  static const Color error = Color(0xFFF44336);
  
  // Exposure Level Colors
  static const Color exposureLow = Color(0xFF4CAF50);
  static const Color exposureMedium = Color(0xFFFF9800);
  static const Color exposureHigh = Color(0xFFFF5722);
  static const Color exposureCritical = Color(0xFFF44336);
  
  // Timer Colors
  static const Color timerActive = Color(0xFF4CAF50);
  static const Color timerPaused = Color(0xFFFF9800);
  static const Color timerCompleted = Color(0xFF2196F3);
  static const Color timerStopped = Color(0xFFF44336);
  
  // Tool Type Colors
  static const Color toolDrill = Color(0xFF2196F3);
  static const Color toolGrinder = Color(0xFFFF5722);
  static const Color toolJackhammer = Color(0xFFF44336);
  static const Color toolSaw = Color(0xFF9C27B0);
  static const Color toolHammer = Color(0xFFFF9800);
  static const Color toolSander = Color(0xFF795548);
  static const Color toolNailer = Color(0xFF607D8B);
  static const Color toolCompressor = Color(0xFF26A69A);
  static const Color toolWelder = Color(0xFFFFC107);
  static const Color toolOther = Color(0xFF9E9E9E);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient safetyGradient = LinearGradient(
    colors: [safe, warning],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient dangerGradient = LinearGradient(
    colors: [warning, danger],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient criticalGradient = LinearGradient(
    colors: [danger, critical],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Helper methods
  static Color getExposureColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return exposureLow;
      case 'medium':
        return exposureMedium;
      case 'high':
        return exposureHigh;
      case 'critical':
        return exposureCritical;
      default:
        return exposureLow;
    }
  }
  
  static Color getToolTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'drill':
        return toolDrill;
      case 'grinder':
        return toolGrinder;
      case 'jackhammer':
        return toolJackhammer;
      case 'saw':
        return toolSaw;
      case 'hammer':
        return toolHammer;
      case 'sander':
        return toolSander;
      case 'nailer':
        return toolNailer;
      case 'compressor':
        return toolCompressor;
      case 'welder':
        return toolWelder;
      default:
        return toolOther;
    }
  }
  
  static Color getTimerStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return timerActive;
      case 'paused':
        return timerPaused;
      case 'completed':
        return timerCompleted;
      case 'stopped':
        return timerStopped;
      default:
        return timerActive;
    }
  }
  
  static Color getRiskColor(double percentage) {
    if (percentage <= 25) return safe;
    if (percentage <= 50) return warning;
    if (percentage <= 75) return danger;
    return critical;
  }
  
  static Color getContrastColor(Color backgroundColor) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? textPrimary : Colors.white;
  }
}
