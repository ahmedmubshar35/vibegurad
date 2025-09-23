import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:stacked/stacked_annotations.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart' hide LazySingleton;

import '../ui/shared/app_theme.dart';
import '../config/app_config.dart';
import '../services/core/authentication_service.dart';
import '../services/core/firebase_service.dart';
import '../services/core/connectivity_service.dart';
import '../services/features/camera_service.dart';
import '../services/features/timer_service.dart';
import '../services/features/ai_service.dart';
import '../services/features/advanced_ai_service.dart';
import '../services/features/offline_ai_service.dart';
import '../services/features/confidence_scoring_service.dart';
import '../services/features/manual_correction_service.dart';
import '../services/features/tool_catalog_service.dart';
import '../services/features/notification_service.dart';
import '../services/features/tool_service.dart';
import '../services/features/session_service.dart';
import '../services/features/qr_scanner_service.dart';
import '../services/features/vibration_service.dart';
import '../services/features/background_timer_service.dart';
import '../services/features/exposure_calculation_service.dart';
import '../services/core/auth_session_service.dart';
import '../services/core/theme_service.dart';
import '../services/core/localization_service.dart';
import '../services/core/accessibility_service.dart';
import '../services/features/onboarding_service.dart';
import '../services/features/help_service.dart';
import '../services/features/feedback_service.dart';
import '../services/features/performance_service.dart';
import '../services/features/crash_reporting_service.dart';
import '../services/features/battery_optimization_service.dart';
import '../services/features/data_usage_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../ui/views/startup/startup_view.dart';
import '../ui/views/authentication/login/login_view.dart';
import '../ui/views/authentication/register/register_view.dart';
import '../ui/views/authentication/forgot_password/forgot_password_view.dart';
import '../ui/views/home/home_view.dart';
import '../ui/views/camera/camera_view.dart';
import '../ui/views/timer/timer_view.dart';
import '../ui/views/profile/profile_view.dart';
import '../ui/views/history/history_view.dart';
import '../ui/views/dashboard/dashboard_view.dart';
import '../ui/views/settings/settings_view.dart';
import '../ui/views/unknown/unknown_view.dart';

import 'app.router.dart';
import 'app.config.dart';

final getIt = GetIt.instance;

@StackedApp(
  routes: [
    MaterialRoute(page: StartupView, initial: true),
    MaterialRoute(page: LoginView),
    MaterialRoute(page: RegisterView),
    MaterialRoute(page: ForgotPasswordView),
    MaterialRoute(page: HomeView),
    MaterialRoute(page: CameraView),
    MaterialRoute(page: TimerView),
    MaterialRoute(page: ProfileView),
    MaterialRoute(page: HistoryView),
    MaterialRoute(page: DashboardView),
    MaterialRoute(page: SettingsView),
    MaterialRoute(page: UnknownView),
  ],
  dependencies: [
    LazySingleton(classType: NavigationService),
    LazySingleton(classType: DialogService),
    LazySingleton(classType: SnackbarService),
    LazySingleton(classType: AuthenticationService),
    LazySingleton(classType: FirebaseService),
    LazySingleton(classType: ConnectivityService),
    LazySingleton(classType: CameraService),
    LazySingleton(classType: TimerService),
    LazySingleton(classType: AiService),
    LazySingleton(classType: AdvancedAIService),
    LazySingleton(classType: OfflineAIService),
    LazySingleton(classType: ConfidenceScoringService),
    LazySingleton(classType: ManualCorrectionService),
    LazySingleton(classType: ToolCatalogService),
    LazySingleton(classType: NotificationService),
    LazySingleton(classType: ToolService),
    LazySingleton(classType: SessionService),
    LazySingleton(classType: QRScannerService),
    LazySingleton(classType: VibrationService),
    LazySingleton(classType: BackgroundTimerService),
    LazySingleton(classType: ExposureCalculationService),
    LazySingleton(classType: AuthSessionService),
    LazySingleton(classType: ThemeService),
    LazySingleton(classType: LocalizationService),
    LazySingleton(classType: AccessibilityService),
  ],
  logger: StackedLogger(),
)
class VibeGuardApp extends StatefulWidget {
  const VibeGuardApp({super.key});

  @override
  State<VibeGuardApp> createState() => _VibeGuardAppState();
}

class _VibeGuardAppState extends State<VibeGuardApp> {
  final ThemeService _themeService = GetIt.instance<ThemeService>();
  final LocalizationService _localizationService = GetIt.instance<LocalizationService>();

  @override
  void initState() {
    super.initState();
    _themeService.addListener(_onChanged);
    _localizationService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onChanged);
    _localizationService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeService.themeMode,

      // Add builder for FlutterToast context
      builder: (context, child) {
        return child ?? const SizedBox.shrink();
      },

      // Localization
      locale: _localizationService.currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocalizationService.supportedLocales,
      // localeResolutionCallback: _localizationService.localeResolutionCallback,
      
      navigatorKey: StackedService.navigatorKey,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      navigatorObservers: [
        StackedService.routeObserver,
      ],
      debugShowCheckedModeBanner: false,
    );
  }
}

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
void configureDependencies() => getIt.init();