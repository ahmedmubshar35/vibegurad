import 'dart:async';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class BatteryOptimizationService with ListenableServiceMixin {
  static const String _batteryOptimizationKey = 'battery_optimization';
  static const String _powerSavingModeKey = 'power_saving_mode';
  
  SharedPreferences? _prefs;
  Timer? _monitoringTimer;
  
  // Battery optimization settings
  bool _isPowerSavingMode = false;
  bool _isBatteryOptimizationEnabled = true;
  int _batteryLevel = 100;
  BatteryStatus _batteryStatus = BatteryStatus.unknown;
  List<BatteryUsageMetric> _batteryUsage = [];
  
  bool get isPowerSavingMode => _isPowerSavingMode;
  bool get isBatteryOptimizationEnabled => _isBatteryOptimizationEnabled;
  int get batteryLevel => _batteryLevel;
  BatteryStatus get batteryStatus => _batteryStatus;
  List<BatteryUsageMetric> get batteryUsage => _batteryUsage;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadBatterySettings();
    _startBatteryMonitoring();
  }
  
  void _startBatteryMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateBatteryMetrics();
    });
  }
  
  Future<void> _updateBatteryMetrics() async {
    try {
      // Update battery level (simplified - would use platform-specific APIs)
      _batteryLevel = await _getBatteryLevel();
      
      // Update battery status
      _batteryStatus = await _getBatteryStatus();
      
      // Create new usage metric
      final metric = BatteryUsageMetric(
        timestamp: DateTime.now(),
        batteryLevel: _batteryLevel,
        batteryStatus: _batteryStatus,
        isPowerSavingMode: _isPowerSavingMode,
      );
      
      // Add to usage list (keep last 100 entries)
      _batteryUsage.add(metric);
      if (_batteryUsage.length > 100) {
        _batteryUsage.removeAt(0);
      }
      
      // Auto-enable power saving mode if battery is low
      if (_batteryLevel <= 20 && !_isPowerSavingMode) {
        await setPowerSavingMode(true);
      }
      
      // Auto-disable power saving mode if battery is high
      if (_batteryLevel >= 80 && _isPowerSavingMode) {
        await setPowerSavingMode(false);
      }
      
      notifyListeners();
    } catch (e) {
      print('Error updating battery metrics: $e');
    }
  }
  
  Future<int> _getBatteryLevel() async {
    try {
      // This would use a battery plugin in a real app
      // For now, return a simulated value
      return 85; // Placeholder
    } catch (e) {
      return 100;
    }
  }
  
  Future<BatteryStatus> _getBatteryStatus() async {
    try {
      // This would use a battery plugin in a real app
      // For now, return a simulated value
      return BatteryStatus.charging; // Placeholder
    } catch (e) {
      return BatteryStatus.unknown;
    }
  }
  
  // Power saving mode
  Future<void> setPowerSavingMode(bool enabled) async {
    _isPowerSavingMode = enabled;
    await _prefs?.setBool(_powerSavingModeKey, enabled);
    
    if (enabled) {
      await _enablePowerSavingFeatures();
    } else {
      await _disablePowerSavingFeatures();
    }
    
    notifyListeners();
  }
  
  Future<void> _enablePowerSavingFeatures() async {
    // Reduce background processing
    // Lower screen brightness
    // Disable animations
    // Reduce network requests
    // Limit background sync
    print('Power saving features enabled');
  }
  
  Future<void> _disablePowerSavingFeatures() async {
    // Restore normal processing
    // Restore screen brightness
    // Enable animations
    // Restore network requests
    // Enable background sync
    print('Power saving features disabled');
  }
  
  // Battery optimization settings
  Future<void> setBatteryOptimizationEnabled(bool enabled) async {
    _isBatteryOptimizationEnabled = enabled;
    await _prefs?.setBool(_batteryOptimizationKey, enabled);
    notifyListeners();
  }
  
  // Get battery optimization recommendations
  List<BatteryOptimizationRecommendation> getBatteryRecommendations() {
    final recommendations = <BatteryOptimizationRecommendation>[];
    
    // Check battery level
    if (_batteryLevel < 20) {
      recommendations.add(BatteryOptimizationRecommendation(
        type: RecommendationType.critical,
        title: 'Low Battery',
        description: 'Your battery is critically low. Enable power saving mode.',
        action: 'Enable Power Saving',
        icon: Icons.battery_alert,
      ));
    } else if (_batteryLevel < 50) {
      recommendations.add(BatteryOptimizationRecommendation(
        type: RecommendationType.warning,
        title: 'Battery Getting Low',
        description: 'Consider enabling power saving mode to extend battery life.',
        action: 'Enable Power Saving',
        icon: Icons.battery_std,
      ));
    }
    
    // Check power saving mode
    if (!_isPowerSavingMode && _batteryLevel < 30) {
      recommendations.add(BatteryOptimizationRecommendation(
        type: RecommendationType.suggestion,
        title: 'Power Saving Available',
        description: 'Enable power saving mode to reduce battery usage.',
        action: 'Enable Power Saving',
        icon: Icons.power_settings_new,
      ));
    }
    
    // Check battery optimization
    if (!_isBatteryOptimizationEnabled) {
      recommendations.add(BatteryOptimizationRecommendation(
        type: RecommendationType.suggestion,
        title: 'Battery Optimization',
        description: 'Enable battery optimization for better power management.',
        action: 'Enable Optimization',
        icon: Icons.settings,
      ));
    }
    
    return recommendations;
  }
  
  // Get battery usage statistics
  BatteryUsageStatistics getBatteryUsageStatistics() {
    if (_batteryUsage.isEmpty) {
      return BatteryUsageStatistics(
        averageBatteryLevel: 0,
        batteryDrainRate: 0,
        powerSavingModeUsage: 0,
        chargingTime: Duration.zero,
        dischargingTime: Duration.zero,
      );
    }
    
    final usage = _batteryUsage;
    final averageBatteryLevel = usage.map((u) => u.batteryLevel).reduce((a, b) => a + b).toDouble() / usage.length;
    
    // Calculate battery drain rate
    double batteryDrainRate = 0;
    if (usage.length > 1) {
      final first = usage.first;
      final last = usage.last;
      final timeDiff = last.timestamp.difference(first.timestamp).inHours;
      if (timeDiff > 0) {
        batteryDrainRate = (first.batteryLevel - last.batteryLevel) / timeDiff;
      }
    }
    
    // Calculate power saving mode usage
    final powerSavingUsage = usage.where((u) => u.isPowerSavingMode).length;
    final powerSavingModeUsage = usage.isNotEmpty ? powerSavingUsage.toDouble() / usage.length : 0.0;
    
    return BatteryUsageStatistics(
      averageBatteryLevel: averageBatteryLevel,
      batteryDrainRate: batteryDrainRate,
      powerSavingModeUsage: powerSavingModeUsage,
      chargingTime: Duration.zero, // Calculate based on battery status changes
      dischargingTime: Duration.zero, // Calculate based on battery status changes
    );
  }
  
  // Load battery settings
  Future<void> _loadBatterySettings() async {
    _isPowerSavingMode = _prefs?.getBool(_powerSavingModeKey) ?? false;
    _isBatteryOptimizationEnabled = _prefs?.getBool(_batteryOptimizationKey) ?? true;
    notifyListeners();
  }
  
  void dispose() {
    _monitoringTimer?.cancel();
  }
}

enum BatteryStatus {
  unknown,
  charging,
  discharging,
  full,
  notCharging,
}

class BatteryUsageMetric {
  final DateTime timestamp;
  final int batteryLevel;
  final BatteryStatus batteryStatus;
  final bool isPowerSavingMode;
  
  BatteryUsageMetric({
    required this.timestamp,
    required this.batteryLevel,
    required this.batteryStatus,
    required this.isPowerSavingMode,
  });
}

class BatteryOptimizationRecommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final String action;
  final IconData icon;
  
  BatteryOptimizationRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
  });
}

enum RecommendationType {
  critical,
  warning,
  suggestion,
  info,
}

class BatteryUsageStatistics {
  final double averageBatteryLevel;
  final double batteryDrainRate;
  final double powerSavingModeUsage;
  final Duration chargingTime;
  final Duration dischargingTime;
  
  BatteryUsageStatistics({
    required this.averageBatteryLevel,
    required this.batteryDrainRate,
    required this.powerSavingModeUsage,
    required this.chargingTime,
    required this.dischargingTime,
  });
}
