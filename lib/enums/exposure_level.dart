enum ExposureLevel {
  low('Low', 'Safe for extended use', 0xFF4CAF50),
  medium('Medium', 'Monitor usage time', 0xFFFF9800),
  high('High', 'Limit daily exposure', 0xFFFF5722),
  critical('Critical', 'Minimize usage', 0xFFF44336);

  const ExposureLevel(this.displayName, this.description, this.color);

  final String displayName;
  final String description;
  final int color;

  // Helper method to get exposure level from vibration value
  static ExposureLevel fromVibrationLevel(double vibrationLevel) {
    if (vibrationLevel <= 2.5) return ExposureLevel.low;
    if (vibrationLevel <= 5.0) return ExposureLevel.medium;
    if (vibrationLevel <= 10.0) return ExposureLevel.high;
    return ExposureLevel.critical;
  }

  // Helper method to get exposure level from usage percentage
  static ExposureLevel fromUsagePercentage(double percentage) {
    if (percentage <= 25) return ExposureLevel.low;
    if (percentage <= 50) return ExposureLevel.medium;
    if (percentage <= 75) return ExposureLevel.high;
    return ExposureLevel.critical;
  }

  // Get warning threshold for this exposure level
  int get warningThresholdMinutes {
    switch (this) {
      case ExposureLevel.low:
        return 60; // 1 hour warning
      case ExposureLevel.medium:
        return 30; // 30 minutes warning
      case ExposureLevel.high:
        return 15; // 15 minutes warning
      case ExposureLevel.critical:
        return 5; // 5 minutes warning
    }
  }

  // Get rest period required after reaching limit
  int get requiredRestMinutes {
    switch (this) {
      case ExposureLevel.low:
        return 10; // 10 minutes rest
      case ExposureLevel.medium:
        return 15; // 15 minutes rest
      case ExposureLevel.high:
        return 30; // 30 minutes rest
      case ExposureLevel.critical:
        return 60; // 1 hour rest
    }
  }

  // Get safety recommendations for this level
  String get safetyRecommendation {
    switch (this) {
      case ExposureLevel.low:
        return 'Continue normal work with regular breaks';
      case ExposureLevel.medium:
        return 'Monitor usage time and take extra breaks';
      case ExposureLevel.high:
        return 'Limit daily exposure and wear protective gear';
      case ExposureLevel.critical:
        return 'Minimize usage and mandatory rest periods';
    }
  }

  // Get icon for this exposure level
  String get icon {
    switch (this) {
      case ExposureLevel.low:
        return '🟢';
      case ExposureLevel.medium:
        return '🟡';
      case ExposureLevel.high:
        return '🟠';
      case ExposureLevel.critical:
        return '🔴';
    }
  }

  // Get notification priority
  int get notificationPriority {
    switch (this) {
      case ExposureLevel.low:
        return 1;
      case ExposureLevel.medium:
        return 2;
      case ExposureLevel.high:
        return 3;
      case ExposureLevel.critical:
        return 4;
    }
  }

  @override
  String toString() => displayName;
}
