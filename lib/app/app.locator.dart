// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:stacked_services/src/dialog/dialog_service.dart';
import 'package:stacked_services/src/navigation/navigation_service.dart';
import 'package:stacked_services/src/snackbar/snackbar_service.dart';
import 'package:stacked_shared/stacked_shared.dart';

import '../services/core/accessibility_service.dart';
import '../services/core/auth_session_service.dart';
import '../services/core/authentication_service.dart';
import '../services/core/connectivity_service.dart';
import '../services/core/firebase_service.dart';
import '../services/core/localization_service.dart';
import '../services/core/theme_service.dart';
import '../services/features/advanced_ai_service.dart';
import '../services/features/ai_service.dart';
import '../services/features/background_timer_service.dart';
import '../services/features/camera_service.dart';
import '../services/features/confidence_scoring_service.dart';
import '../services/features/exposure_calculation_service.dart';
import '../services/features/manual_correction_service.dart';
import '../services/features/notification_service.dart';
import '../services/features/offline_ai_service.dart';
import '../services/features/qr_scanner_service.dart';
import '../services/features/session_service.dart';
import '../services/features/timer_service.dart';
import '../services/features/tool_catalog_service.dart';
import '../services/features/tool_service.dart';
import '../services/features/vibration_service.dart';
import '../services/features/onboarding_service.dart';
import '../services/features/help_service.dart';
import '../services/features/feedback_service.dart';
import '../services/features/performance_service.dart';
import '../services/features/crash_reporting_service.dart';
import '../services/features/battery_optimization_service.dart';
import '../services/features/data_usage_service.dart';

final locator = StackedLocator.instance;

Future<void> setupLocator({
  String? environment,
  EnvironmentFilter? environmentFilter,
}) async {
// Register environments
  locator.registerEnvironment(
      environment: environment, environmentFilter: environmentFilter);

// Register dependencies
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => SnackbarService());
  locator.registerLazySingleton(() => AuthenticationService());
  locator.registerLazySingleton(() => FirebaseService());
  locator.registerLazySingleton(() => ConnectivityService());
  locator.registerLazySingleton(() => CameraService());
  locator.registerLazySingleton(() => TimerService());
  locator.registerLazySingleton(() => AiService());
  locator.registerLazySingleton(() => AdvancedAIService());
  locator.registerLazySingleton(() => OfflineAIService());
  locator.registerLazySingleton(() => ConfidenceScoringService());
  locator.registerLazySingleton(() => ManualCorrectionService());
  locator.registerLazySingleton(() => ToolCatalogService());
  locator.registerLazySingleton(() => NotificationService());
  locator.registerLazySingleton(() => ToolService());
  locator.registerLazySingleton(() => SessionService());
  locator.registerLazySingleton(() => QRScannerService());
  locator.registerLazySingleton(() => VibrationService());
  locator.registerLazySingleton(() => BackgroundTimerService());
  locator.registerLazySingleton(() => ExposureCalculationService());
  locator.registerLazySingleton(() => AuthSessionService());
  locator.registerLazySingleton(() => ThemeService());
  locator.registerLazySingleton(() => LocalizationService());
  locator.registerLazySingleton(() => AccessibilityService());
  locator.registerLazySingleton(() => OnboardingService());
  locator.registerLazySingleton(() => HelpService());
  locator.registerLazySingleton(() => FeedbackService());
  locator.registerLazySingleton(() => PerformanceService());
  locator.registerLazySingleton(() => CrashReportingService());
  locator.registerLazySingleton(() => BatteryOptimizationService());
  locator.registerLazySingleton(() => DataUsageService());
}
