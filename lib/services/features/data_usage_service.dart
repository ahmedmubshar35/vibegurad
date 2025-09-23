import 'dart:async';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

@lazySingleton
class DataUsageService with ListenableServiceMixin {
  static const String _dataUsageKey = 'data_usage';
  static const String _dataSavingModeKey = 'data_saving_mode';
  static const String _wifiOnlyModeKey = 'wifi_only_mode';
  
  SharedPreferences? _prefs;
  Timer? _monitoringTimer;
  
  // Data usage settings
  bool _isDataSavingMode = false;
  bool _isWifiOnlyMode = false;
  double _dataUsageToday = 0.0;
  double _dataUsageThisMonth = 0.0;
  List<DataUsageMetric> _dataUsageHistory = [];
  ConnectivityResult _connectionType = ConnectivityResult.none;
  
  bool get isDataSavingMode => _isDataSavingMode;
  bool get isWifiOnlyMode => _isWifiOnlyMode;
  double get dataUsageToday => _dataUsageToday;
  double get dataUsageThisMonth => _dataUsageThisMonth;
  List<DataUsageMetric> get dataUsageHistory => _dataUsageHistory;
  ConnectivityResult get connectionType => _connectionType;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadDataUsageSettings();
    _startDataMonitoring();
  }
  
  void _startDataMonitoring() {
    _monitoringTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateDataUsageMetrics();
    });
  }
  
  Future<void> _updateDataUsageMetrics() async {
    try {
      // Update connection type
      final connectivity = Connectivity();
      _connectionType = await connectivity.checkConnectivity();
      
      // Simulate data usage (in a real app, you'd track actual network usage)
      final currentUsage = await _getCurrentDataUsage();
      _dataUsageToday = currentUsage;
      
      // Create new usage metric
      final metric = DataUsageMetric(
        timestamp: DateTime.now(),
        dataUsed: currentUsage,
        connectionType: _connectionType,
        isDataSavingMode: _isDataSavingMode,
        isWifiOnlyMode: _isWifiOnlyMode,
      );
      
      // Add to history (keep last 100 entries)
      _dataUsageHistory.add(metric);
      if (_dataUsageHistory.length > 100) {
        _dataUsageHistory.removeAt(0);
      }
      
      // Calculate monthly usage
      _dataUsageThisMonth = _calculateMonthlyUsage();
      
      notifyListeners();
    } catch (e) {
      print('Error updating data usage metrics: $e');
    }
  }
  
  Future<double> _getCurrentDataUsage() async {
    try {
      // This would track actual network usage in a real app
      // For now, return a simulated value
      return 15.5; // MB
    } catch (e) {
      return 0.0;
    }
  }
  
  double _calculateMonthlyUsage() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return _dataUsageHistory
        .where((metric) => metric.timestamp.isAfter(startOfMonth))
        .fold(0.0, (sum, metric) => sum + metric.dataUsed);
  }
  
  // Data saving mode
  Future<void> setDataSavingMode(bool enabled) async {
    _isDataSavingMode = enabled;
    await _prefs?.setBool(_dataSavingModeKey, enabled);
    
    if (enabled) {
      await _enableDataSavingFeatures();
    } else {
      await _disableDataSavingFeatures();
    }
    
    notifyListeners();
  }
  
  Future<void> _enableDataSavingFeatures() async {
    // Reduce image quality
    // Compress data transfers
    // Limit background sync
    // Use cached data when possible
    // Reduce API calls
    print('Data saving features enabled');
  }
  
  Future<void> _disableDataSavingFeatures() async {
    // Restore normal image quality
    // Restore normal data transfers
    // Enable background sync
    // Use fresh data
    // Restore API calls
    print('Data saving features disabled');
  }
  
  // WiFi only mode
  Future<void> setWifiOnlyMode(bool enabled) async {
    _isWifiOnlyMode = enabled;
    await _prefs?.setBool(_wifiOnlyModeKey, enabled);
    notifyListeners();
  }
  
  // Check if data usage is allowed based on current settings
  bool isDataUsageAllowed() {
    if (_isWifiOnlyMode && _connectionType != ConnectivityResult.wifi) {
      return false;
    }
    return true;
  }
  
  // Get data usage recommendations
  List<DataUsageRecommendation> getDataUsageRecommendations() {
    final recommendations = <DataUsageRecommendation>[];
    
    // Check if using mobile data
    if (_connectionType == ConnectivityResult.mobile) {
      recommendations.add(DataUsageRecommendation(
        type: RecommendationType.warning,
        title: 'Using Mobile Data',
        description: 'You\'re currently using mobile data. Consider connecting to WiFi to save data.',
        action: 'Enable WiFi Only Mode',
        icon: Icons.wifi_off,
      ));
    }
    
    // Check daily data usage
    if (_dataUsageToday > 100) { // 100 MB threshold
      recommendations.add(DataUsageRecommendation(
        type: RecommendationType.warning,
        title: 'High Daily Data Usage',
        description: 'You\'ve used ${_dataUsageToday.toStringAsFixed(1)} MB today. Consider enabling data saving mode.',
        action: 'Enable Data Saving',
        icon: Icons.data_usage,
      ));
    }
    
    // Check monthly data usage
    if (_dataUsageThisMonth > 1000) { // 1 GB threshold
      recommendations.add(DataUsageRecommendation(
        type: RecommendationType.critical,
        title: 'High Monthly Data Usage',
        description: 'You\'ve used ${_dataUsageThisMonth.toStringAsFixed(1)} MB this month. Enable data saving mode.',
        action: 'Enable Data Saving',
        icon: Icons.warning,
      ));
    }
    
    // Check data saving mode
    if (!_isDataSavingMode && _dataUsageToday > 50) {
      recommendations.add(DataUsageRecommendation(
        type: RecommendationType.suggestion,
        title: 'Data Saving Available',
        description: 'Enable data saving mode to reduce data usage.',
        action: 'Enable Data Saving',
        icon: Icons.save,
      ));
    }
    
    return recommendations;
  }
  
  // Get data usage statistics
  DataUsageStatistics getDataUsageStatistics() {
    if (_dataUsageHistory.isEmpty) {
      return DataUsageStatistics(
        totalDataUsed: 0,
        averageDailyUsage: 0,
        peakUsage: 0,
        wifiUsage: 0,
        mobileUsage: 0,
        dataSavingModeUsage: 0,
      );
    }
    
    final history = _dataUsageHistory;
    final totalDataUsed = history.fold(0.0, (sum, metric) => sum + metric.dataUsed);
    final averageDailyUsage = totalDataUsed / history.length;
    final peakUsage = history.map((m) => m.dataUsed).reduce((a, b) => a > b ? a : b);
    
    final wifiUsage = history
        .where((m) => m.connectionType == ConnectivityResult.wifi)
        .fold(0.0, (sum, metric) => sum + metric.dataUsed);
    
    final mobileUsage = history
        .where((m) => m.connectionType == ConnectivityResult.mobile)
        .fold(0.0, (sum, metric) => sum + metric.dataUsed);
    
    final dataSavingModeUsage = history
        .where((m) => m.isDataSavingMode)
        .fold(0.0, (sum, metric) => sum + metric.dataUsed);
    
    return DataUsageStatistics(
      totalDataUsed: totalDataUsed,
      averageDailyUsage: averageDailyUsage,
      peakUsage: peakUsage,
      wifiUsage: wifiUsage,
      mobileUsage: mobileUsage,
      dataSavingModeUsage: dataSavingModeUsage,
    );
  }
  
  // Load data usage settings
  Future<void> _loadDataUsageSettings() async {
    _isDataSavingMode = _prefs?.getBool(_dataSavingModeKey) ?? false;
    _isWifiOnlyMode = _prefs?.getBool(_wifiOnlyModeKey) ?? false;
    notifyListeners();
  }
  
  // Reset data usage statistics
  Future<void> resetDataUsageStatistics() async {
    _dataUsageToday = 0.0;
    _dataUsageThisMonth = 0.0;
    _dataUsageHistory = [];
    await _prefs?.remove(_dataUsageKey);
    notifyListeners();
  }
  
  // Additional getters needed by the view
  int get dataLimitMB => 1000; // Default 1GB limit
  double get averageDailyUsage => getDataUsageStatistics().averageDailyUsage;
  String get peakUsageDay => 'Monday'; // Simplified for now
  double get dataSavedThisMonth => _isDataSavingMode ? _dataUsageThisMonth * 0.3 : 0.0; // Estimated 30% savings
  double get wifiUsagePercentage {
    final stats = getDataUsageStatistics();
    final total = stats.wifiUsage + stats.mobileUsage;
    return total > 0 ? (stats.wifiUsage / total) * 100 : 0.0;
  }

  // Refresh data method
  Future<void> refreshData() async {
    await _updateDataUsageMetrics();
  }

  // Set data limit
  Future<void> setDataLimit(int limitMB) async {
    // In a real implementation, this would save to preferences
    // For now, just notify listeners
    notifyListeners();
  }

  void dispose() {
    _monitoringTimer?.cancel();
  }
}

enum RecommendationType {
  critical,
  warning,
  suggestion,
  info,
}

class DataUsageMetric {
  final DateTime timestamp;
  final double dataUsed;
  final ConnectivityResult connectionType;
  final bool isDataSavingMode;
  final bool isWifiOnlyMode;
  
  DataUsageMetric({
    required this.timestamp,
    required this.dataUsed,
    required this.connectionType,
    required this.isDataSavingMode,
    required this.isWifiOnlyMode,
  });
}

class DataUsageRecommendation {
  final RecommendationType type;
  final String title;
  final String description;
  final String action;
  final IconData icon;
  
  DataUsageRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
  });
}

class DataUsageStatistics {
  final double totalDataUsed;
  final double averageDailyUsage;
  final double peakUsage;
  final double wifiUsage;
  final double mobileUsage;
  final double dataSavingModeUsage;
  
  DataUsageStatistics({
    required this.totalDataUsed,
    required this.averageDailyUsage,
    required this.peakUsage,
    required this.wifiUsage,
    required this.mobileUsage,
    required this.dataSavingModeUsage,
  });
}
