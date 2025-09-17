import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@lazySingleton
class CrashReportingService with ListenableServiceMixin {
  static const String _crashReportsCollection = 'crash_reports';
  static const String _crashDataKey = 'crash_data';
  
  SharedPreferences? _prefs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Crash tracking
  List<CrashReport> _crashReports = [];
  bool _isCrashReportingEnabled = true;
  
  List<CrashReport> get crashReports => _crashReports;
  bool get isCrashReportingEnabled => _isCrashReportingEnabled;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCrashData();
    _setupCrashHandlers();
  }
  
  void _setupCrashHandlers() {
    // Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _reportCrash(
        error: details.exception.toString(),
        stackTrace: details.stack?.toString() ?? '',
        context: 'Flutter Error',
        severity: CrashSeverity.error,
      );
    };
    
    // Platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportCrash(
        error: error.toString(),
        stackTrace: stack.toString(),
        context: 'Platform Error',
        severity: CrashSeverity.critical,
      );
      return true;
    };
  }
  
  Future<void> _reportCrash({
    required String error,
    required String stackTrace,
    required String context,
    required CrashSeverity severity,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_isCrashReportingEnabled) return;
    
    try {
      final crashReport = CrashReport(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        error: error,
        stackTrace: stackTrace,
        context: context,
        severity: severity,
        timestamp: DateTime.now(),
        deviceInfo: await _getDeviceInfo(),
        appVersion: '1.0.0', // Get from app config
        additionalData: additionalData ?? {},
        isResolved: false,
      );
      
      // Add to local list
      _crashReports.add(crashReport);
      
      // Save to Firestore
      await _firestore
          .collection(_crashReportsCollection)
          .doc(crashReport.id)
          .set(crashReport.toMap());
      
      // Save to local storage
      await _saveCrashData();
      
      notifyListeners();
    } catch (e) {
      print('Error reporting crash: $e');
    }
  }
  
  // Manual crash reporting
  Future<void> reportCrash({
    required String error,
    required String stackTrace,
    required String context,
    CrashSeverity severity = CrashSeverity.error,
    Map<String, dynamic>? additionalData,
  }) async {
    await _reportCrash(
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      additionalData: additionalData,
    );
  }
  
  // Report non-fatal issues
  Future<void> reportIssue({
    required String issue,
    required String description,
    Map<String, dynamic>? additionalData,
  }) async {
    await _reportCrash(
      error: issue,
      stackTrace: description,
      context: 'User Reported Issue',
      severity: CrashSeverity.warning,
      additionalData: additionalData,
    );
  }
  
  // Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'locale': Platform.localeName,
    };
  }
  
  // Load crash data from local storage
  Future<void> _loadCrashData() async {
    try {
      final data = _prefs?.getString(_crashDataKey);
      if (data != null) {
        // Parse and load crash data
        // This would be more complex in a real implementation
      }
    } catch (e) {
      print('Error loading crash data: $e');
    }
  }
  
  // Save crash data to local storage
  Future<void> _saveCrashData() async {
    try {
      // Save crash data to preferences
      // This would be more complex in a real implementation
    } catch (e) {
      print('Error saving crash data: $e');
    }
  }
  
  // Get crash statistics
  CrashStatistics getCrashStatistics() {
    final reports = _crashReports;
    if (reports.isEmpty) {
      return CrashStatistics(
        totalCrashes: 0,
        criticalCrashes: 0,
        errorCrashes: 0,
        warningCrashes: 0,
        resolvedCrashes: 0,
        averageResolutionTime: Duration.zero,
      );
    }
    
    final criticalCrashes = reports.where((r) => r.severity == CrashSeverity.critical).length;
    final errorCrashes = reports.where((r) => r.severity == CrashSeverity.error).length;
    final warningCrashes = reports.where((r) => r.severity == CrashSeverity.warning).length;
    final resolvedCrashes = reports.where((r) => r.isResolved).length;
    
    return CrashStatistics(
      totalCrashes: reports.length,
      criticalCrashes: criticalCrashes,
      errorCrashes: errorCrashes,
      warningCrashes: warningCrashes,
      resolvedCrashes: resolvedCrashes,
      averageResolutionTime: Duration.zero, // Calculate based on resolved crashes
    );
  }
  
  // Toggle crash reporting
  Future<void> setCrashReportingEnabled(bool enabled) async {
    _isCrashReportingEnabled = enabled;
    await _prefs?.setBool('crash_reporting_enabled', enabled);
    notifyListeners();
  }
  
  // Mark crash as resolved
  Future<void> markCrashAsResolved(String crashId) async {
    try {
      final index = _crashReports.indexWhere((r) => r.id == crashId);
      if (index != -1) {
        _crashReports[index] = _crashReports[index].copyWith(isResolved: true);
        
        // Update in Firestore
        await _firestore
            .collection(_crashReportsCollection)
            .doc(crashId)
            .update({'isResolved': true});
        
        await _saveCrashData();
        notifyListeners();
      }
    } catch (e) {
      print('Error marking crash as resolved: $e');
    }
  }
  
  // Clear all crash reports
  Future<void> clearAllCrashReports() async {
    try {
      _crashReports = [];
      await _prefs?.remove(_crashDataKey);
      notifyListeners();
    } catch (e) {
      print('Error clearing crash reports: $e');
    }
  }
}

enum CrashSeverity {
  critical,
  error,
  warning,
  info,
}

class CrashReport {
  final String id;
  final String error;
  final String stackTrace;
  final String context;
  final CrashSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final String appVersion;
  final Map<String, dynamic> additionalData;
  final bool isResolved;
  
  CrashReport({
    required this.id,
    required this.error,
    required this.stackTrace,
    required this.context,
    required this.severity,
    required this.timestamp,
    required this.deviceInfo,
    required this.appVersion,
    required this.additionalData,
    required this.isResolved,
  });
  
  CrashReport copyWith({
    String? id,
    String? error,
    String? stackTrace,
    String? context,
    CrashSeverity? severity,
    DateTime? timestamp,
    Map<String, dynamic>? deviceInfo,
    String? appVersion,
    Map<String, dynamic>? additionalData,
    bool? isResolved,
  }) {
    return CrashReport(
      id: id ?? this.id,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      context: context ?? this.context,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      appVersion: appVersion ?? this.appVersion,
      additionalData: additionalData ?? this.additionalData,
      isResolved: isResolved ?? this.isResolved,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'error': error,
      'stackTrace': stackTrace,
      'context': context,
      'severity': severity.name,
      'timestamp': timestamp.toIso8601String(),
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
      'additionalData': additionalData,
      'isResolved': isResolved,
    };
  }
  
  factory CrashReport.fromMap(Map<String, dynamic> map) {
    return CrashReport(
      id: map['id'] ?? '',
      error: map['error'] ?? '',
      stackTrace: map['stackTrace'] ?? '',
      context: map['context'] ?? '',
      severity: CrashSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => CrashSeverity.error,
      ),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] ?? {}),
      appVersion: map['appVersion'] ?? '1.0.0',
      additionalData: Map<String, dynamic>.from(map['additionalData'] ?? {}),
      isResolved: map['isResolved'] ?? false,
    );
  }
}

class CrashStatistics {
  final int totalCrashes;
  final int criticalCrashes;
  final int errorCrashes;
  final int warningCrashes;
  final int resolvedCrashes;
  final Duration averageResolutionTime;
  
  CrashStatistics({
    required this.totalCrashes,
    required this.criticalCrashes,
    required this.errorCrashes,
    required this.warningCrashes,
    required this.resolvedCrashes,
    required this.averageResolutionTime,
  });
  
  double get resolutionRate {
    if (totalCrashes == 0) return 0.0;
    return resolvedCrashes / totalCrashes;
  }
}
