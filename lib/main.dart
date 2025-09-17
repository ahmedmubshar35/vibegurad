import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get_it/get_it.dart';

import 'app/app.dart';
import 'app/app.locator.dart';
import 'services/core/theme_service.dart';
import 'services/core/localization_service.dart';
import 'services/core/accessibility_service.dart';
import 'services/features/onboarding_service.dart';
import 'services/features/feedback_service.dart';
import 'services/features/performance_service.dart';
import 'services/features/crash_reporting_service.dart';
import 'services/features/battery_optimization_service.dart';
import 'services/features/data_usage_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Setup locator and dependency injection
    await setupLocator();

    // Initialize services with error handling
    await GetIt.instance<ThemeService>().initialize();
    await GetIt.instance<LocalizationService>().initialize();
    await GetIt.instance<AccessibilityService>().initialize();
    await GetIt.instance<OnboardingService>().initialize();
    await GetIt.instance<FeedbackService>().initialize();
    await GetIt.instance<PerformanceService>().initialize();
    await GetIt.instance<CrashReportingService>().initialize();
    await GetIt.instance<BatteryOptimizationService>().initialize();
    await GetIt.instance<DataUsageService>().initialize();

    runApp(const VibeGuardApp());
  } catch (e) {
    // Fallback app in case of initialization error
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('App initialization failed'),
              SizedBox(height: 8),
              Text('Error: $e', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ));
  }
}
