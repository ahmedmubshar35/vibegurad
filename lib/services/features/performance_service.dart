import 'dart:async';
import 'dart:io';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class PerformanceService with ListenableServiceMixin {
  static const String _performanceDataKey = 'performance_data';
  
  SharedPreferences? _prefs;
  Timer? _monitoringTimer;
  
  // Performance metrics
  double _memoryUsage = 0.0;
  double _cpuUsage = 0.0;
  int _batteryLevel = 100;
  double _appSize = 0.0;
  Duration _appLaunchTime = Duration.zero;
  List<PerformanceMetric> _metrics = [];
  
  double get memoryUsage => _memoryUsage;
  double get cpuUsage => _cpuUsage;
  int get batteryLevel => _batteryLevel;
  double get appSize => _appSize;
  Duration get appLaunchTime => _appLaunchTime;
  List<PerformanceMetric> get metrics => _metrics;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPerformanceData();
    _startMonitoring();
  }
  
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateMetrics();
    });
  }
  
  Future<void> _updateMetrics() async {
    try {
      // Update memory usage
      _memoryUsage = await _getMemoryUsage();
      
      // Update CPU usage (simplified)
      _cpuUsage = await _getCpuUsage();
      
      // Update battery level
      _batteryLevel = await _getBatteryLevel();
      
      // Create new metric entry
      final metric = PerformanceMetric(
        timestamp: DateTime.now(),
        memoryUsage: _memoryUsage,
        cpuUsage: _cpuUsage,
        batteryLevel: _batteryLevel,
        appSize: _appSize,
      );
      
      // Add to metrics list (keep last 100 entries)
      _metrics.add(metric);
      if (_metrics.length > 100) {
        _metrics.removeAt(0);
      }
      
      // Save to preferences
      await _savePerformanceData();
      
      notifyListeners();
    } catch (e) {
      print('Error updating performance metrics: $e');
    }
  }
  
  Future<double> _getMemoryUsage() async {
    try {
      // This is a simplified implementation
      // In a real app, you'd use platform-specific APIs
      return (ProcessInfo.currentRss / 1024 / 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
  
  Future<double> _getCpuUsage() async {
    try {
      // Simplified CPU usage calculation
      // In a real app, you'd use platform-specific APIs
      return 0.0; // Placeholder
    } catch (e) {
      return 0.0;
    }
  }
  
  Future<int> _getBatteryLevel() async {
    try {
      // This would require a battery plugin
      // For now, return a placeholder
      return 85; // Placeholder
    } catch (e) {
      return 100;
    }
  }
  
  void recordAppLaunchTime(Duration launchTime) {
    _appLaunchTime = launchTime;
    notifyListeners();
  }
  
  void recordAppSize(double size) {
    _appSize = size;
    notifyListeners();
  }
  
  // Performance analysis
  PerformanceAnalysis getPerformanceAnalysis() {
    if (_metrics.isEmpty) {
      return PerformanceAnalysis(
        status: PerformanceStatus.unknown,
        score: 0,
        recommendations: ['No performance data available'],
        averageMemoryUsage: 0.0,
        averageCpuUsage: 0.0,
        averageBatteryLevel: 0.0,
      );
    }
    
    final recentMetrics = _metrics.take(10).toList();
    final avgMemory = recentMetrics.map((m) => m.memoryUsage).reduce((a, b) => a + b) / recentMetrics.length;
    final avgCpu = recentMetrics.map((m) => m.cpuUsage).reduce((a, b) => a + b) / recentMetrics.length;
    final avgBattery = recentMetrics.map((m) => m.batteryLevel).reduce((a, b) => a + b) / recentMetrics.length;
    
    int score = 100;
    List<String> recommendations = [];
    
    // Memory analysis
    if (avgMemory > 200) {
      score -= 20;
      recommendations.add('High memory usage detected. Consider closing unused apps.');
    } else if (avgMemory > 150) {
      score -= 10;
      recommendations.add('Memory usage is moderate. Monitor for potential issues.');
    }
    
    // CPU analysis
    if (avgCpu > 80) {
      score -= 20;
      recommendations.add('High CPU usage detected. App may be running slowly.');
    } else if (avgCpu > 60) {
      score -= 10;
      recommendations.add('CPU usage is moderate. Performance may be affected.');
    }
    
    // Battery analysis
    if (avgBattery < 20) {
      score -= 15;
      recommendations.add('Low battery level. Consider charging your device.');
    } else if (avgBattery < 50) {
      score -= 5;
      recommendations.add('Battery level is getting low.');
    }
    
    // Launch time analysis
    if (_appLaunchTime.inMilliseconds > 3000) {
      score -= 15;
      recommendations.add('App launch time is slow. Consider optimizing startup.');
    } else if (_appLaunchTime.inMilliseconds > 2000) {
      score -= 5;
      recommendations.add('App launch time could be improved.');
    }
    
    PerformanceStatus status;
    if (score >= 90) {
      status = PerformanceStatus.excellent;
    } else if (score >= 75) {
      status = PerformanceStatus.good;
    } else if (score >= 60) {
      status = PerformanceStatus.fair;
    } else {
      status = PerformanceStatus.poor;
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Performance is optimal. Keep up the good work!');
    }
    
    return PerformanceAnalysis(
      status: status,
      score: score,
      recommendations: recommendations,
      averageMemoryUsage: avgMemory,
      averageCpuUsage: avgCpu,
      averageBatteryLevel: avgBattery,
    );
  }
  
  Future<void> _loadPerformanceData() async {
    try {
      final data = _prefs?.getString(_performanceDataKey);
      if (data != null) {
        // Parse and load performance data
        // This would be more complex in a real implementation
      }
    } catch (e) {
      print('Error loading performance data: $e');
    }
  }
  
  Future<void> _savePerformanceData() async {
    try {
      // Save performance data to preferences
      // This would be more complex in a real implementation
    } catch (e) {
      print('Error saving performance data: $e');
    }
  }
  
  void dispose() {
    _monitoringTimer?.cancel();
  }
}

class PerformanceMetric {
  final DateTime timestamp;
  final double memoryUsage;
  final double cpuUsage;
  final int batteryLevel;
  final double appSize;
  
  PerformanceMetric({
    required this.timestamp,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.batteryLevel,
    required this.appSize,
  });
}

class PerformanceAnalysis {
  final PerformanceStatus status;
  final int score;
  final List<String> recommendations;
  final double averageMemoryUsage;
  final double averageCpuUsage;
  final double averageBatteryLevel;
  
  PerformanceAnalysis({
    required this.status,
    required this.score,
    required this.recommendations,
    required this.averageMemoryUsage,
    required this.averageCpuUsage,
    required this.averageBatteryLevel,
  });
}

enum PerformanceStatus {
  excellent,
  good,
  fair,
  poor,
  unknown,
}
