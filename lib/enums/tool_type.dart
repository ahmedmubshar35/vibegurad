enum ToolType {
  drill('Drill', 'Rotary drilling tool', 'assets/icons/drill.png'),
  grinder('Grinder', 'Angle grinder for cutting/grinding', 'assets/icons/grinder.png'),
  jackhammer('Jackhammer', 'Pneumatic hammer for breaking', 'assets/icons/jackhammer.png'),
  saw('Saw', 'Cutting saw (circular, reciprocating)', 'assets/icons/saw.png'),
  hammer('Hammer', 'Impact hammer or demolition tool', 'assets/icons/hammer.png'),
  sander('Sander', 'Sanding and polishing tool', 'assets/icons/sander.png'),
  nailer('Nailer', 'Pneumatic nail gun', 'assets/icons/nailer.png'),
  compressor('Compressor', 'Air compressor', 'assets/icons/compressor.png'),
  welder('Welder', 'Welding equipment', 'assets/icons/welder.png'),
  other('Other', 'Other power tools', 'assets/icons/tool.png');

  const ToolType(this.displayName, this.description, this.iconPath);

  final String displayName;
  final String description;
  final String iconPath;

  // Helper method to get tool type from string
  static ToolType fromString(String value) {
    return ToolType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => ToolType.other,
    );
  }

  // Default vibration levels for each tool type (m/s²)
  double get defaultVibrationLevel {
    switch (this) {
      case ToolType.drill:
        return 2.5;
      case ToolType.grinder:
        return 4.0;
      case ToolType.jackhammer:
        return 8.0;
      case ToolType.saw:
        return 3.5;
      case ToolType.hammer:
        return 6.0;
      case ToolType.sander:
        return 3.0;
      case ToolType.nailer:
        return 5.0;
      case ToolType.compressor:
        return 1.5;
      case ToolType.welder:
        return 2.0;
      case ToolType.other:
        return 3.0;
    }
  }

  // Default daily exposure limits (minutes)
  int get defaultDailyLimit {
    switch (this) {
      case ToolType.drill:
        return 480; // 8 hours
      case ToolType.grinder:
        return 300; // 5 hours
      case ToolType.jackhammer:
        return 150; // 2.5 hours
      case ToolType.saw:
        return 400; // 6.7 hours
      case ToolType.hammer:
        return 200; // 3.3 hours
      case ToolType.sander:
        return 350; // 5.8 hours
      case ToolType.nailer:
        return 250; // 4.2 hours
      case ToolType.compressor:
        return 600; // 10 hours
      case ToolType.welder:
        return 450; // 7.5 hours
      case ToolType.other:
        return 400; // 6.7 hours
    }
  }

  // Default frequency ranges (Hz)
  double get defaultFrequency {
    switch (this) {
      case ToolType.drill:
        return 50.0;
      case ToolType.grinder:
        return 100.0;
      case ToolType.jackhammer:
        return 25.0;
      case ToolType.saw:
        return 60.0;
      case ToolType.hammer:
        return 30.0;
      case ToolType.sander:
        return 80.0;
      case ToolType.nailer:
        return 40.0;
      case ToolType.compressor:
        return 20.0;
      case ToolType.welder:
        return 15.0;
      case ToolType.other:
        return 50.0;
    }
  }

  // Risk level based on vibration
  String get riskLevel {
    if (defaultVibrationLevel <= 2.5) return 'Low';
    if (defaultVibrationLevel <= 5.0) return 'Medium';
    if (defaultVibrationLevel <= 10.0) return 'High';
    return 'Critical';
  }

  // Safety recommendations
  String get safetyRecommendation {
    switch (this) {
      case ToolType.drill:
        return 'Use anti-vibration gloves and take regular breaks';
      case ToolType.grinder:
        return 'High vibration - limit daily use and wear protective gear';
      case ToolType.jackhammer:
        return 'Critical vibration - minimize usage and mandatory rest periods';
      case ToolType.saw:
        return 'Moderate vibration - monitor usage time';
      case ToolType.hammer:
        return 'High vibration - use with caution and limit exposure';
      case ToolType.sander:
        return 'Moderate vibration - take regular breaks';
      case ToolType.nailer:
        return 'High vibration - wear anti-vibration gloves';
      case ToolType.compressor:
        return 'Low vibration - generally safe for extended use';
      case ToolType.welder:
        return 'Low vibration - focus on other safety concerns';
      case ToolType.other:
        return 'Assess vibration level and follow safety guidelines';
    }
  }

  @override
  String toString() => displayName;
}
