import 'package:stacked/stacked.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/material.dart';

import '../../../services/features/data_usage_service.dart';

class DataUsageViewModel extends BaseViewModel {
  final DataUsageService _dataUsageService = GetIt.instance<DataUsageService>();

  // Getters
  bool get isDataSavingMode => _dataUsageService.isDataSavingMode;
  bool get isWifiOnlyMode => _dataUsageService.isWifiOnlyMode;
  double get dataUsageToday => _dataUsageService.dataUsageToday;
  double get dataUsageThisMonth => _dataUsageService.dataUsageThisMonth;
  String get connectionType => _dataUsageService.connectionType.name;
  int get dataLimitMB => _dataUsageService.dataLimitMB;
  double get averageDailyUsage => _dataUsageService.averageDailyUsage;
  String get peakUsageDay => _dataUsageService.peakUsageDay;
  double get dataSavedThisMonth => _dataUsageService.dataSavedThisMonth;
  double get wifiUsagePercentage => _dataUsageService.wifiUsagePercentage;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshData() async {
    setBusy(true);
    try {
      await _dataUsageService.refreshData();
      notifyListeners();
    } catch (e) {
      // Handle error
      print('Error refreshing data usage: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> toggleDataSavingMode(bool value) async {
    await _dataUsageService.setDataSavingMode(value);
    notifyListeners();
  }

  Future<void> toggleWifiOnlyMode(bool value) async {
    await _dataUsageService.setWifiOnlyMode(value);
    notifyListeners();
  }

  Future<void> setDataLimit(int limitMB) async {
    await _dataUsageService.setDataLimit(limitMB);
    notifyListeners();
  }

  List<Map<String, dynamic>> getDataRecommendations() {
    final recommendations = <Map<String, dynamic>>[];

    // High data usage warning
    if (dataUsageThisMonth > dataLimitMB * 0.8) {
      recommendations.add({
        'type': 'warning',
        'title': 'High Data Usage',
        'description': 'You\'ve used ${(dataUsageThisMonth / dataLimitMB * 100).toStringAsFixed(0)}% of your monthly limit.',
        'icon': Icons.warning_amber,
        'action': 'Enable Data Saving',
      });
    }

    // WiFi recommendation
    if (wifiUsagePercentage < 50 && !isWifiOnlyMode) {
      recommendations.add({
        'type': 'suggestion',
        'title': 'Use WiFi More',
        'description': 'Consider enabling WiFi-only mode to reduce mobile data usage.',
        'icon': Icons.wifi,
        'action': 'Enable WiFi Only',
      });
    }

    // Data saving mode recommendation
    if (!isDataSavingMode && dataUsageThisMonth > dataLimitMB * 0.6) {
      recommendations.add({
        'type': 'suggestion',
        'title': 'Enable Data Saving',
        'description': 'Data saving mode can help reduce your monthly usage.',
        'icon': Icons.data_saver_on,
        'action': 'Enable',
      });
    }

    // Critical data limit
    if (dataUsageThisMonth >= dataLimitMB) {
      recommendations.add({
        'type': 'critical',
        'title': 'Data Limit Exceeded',
        'description': 'You\'ve exceeded your monthly data limit. Consider increasing your limit or reducing usage.',
        'icon': Icons.error,
        'action': 'Increase Limit',
      });
    }

    return recommendations;
  }
}


