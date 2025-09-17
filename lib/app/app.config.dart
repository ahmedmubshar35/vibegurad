// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../services/core/accessibility_service.dart' as _i431;
import '../services/core/auth_session_service.dart' as _i992;
import '../services/core/authentication_service.dart' as _i1028;
import '../services/core/connectivity_service.dart' as _i708;
import '../services/core/firebase_service.dart' as _i918;
import '../services/core/localization_service.dart' as _i1031;
import '../services/core/theme_service.dart' as _i312;
import '../services/features/advanced_ai_service.dart' as _i473;
import '../services/features/ai_service.dart' as _i689;
import '../services/features/audio_alert_service.dart' as _i778;
import '../services/features/background_timer_service.dart' as _i288;
import '../services/features/camera_service.dart' as _i304;
import '../services/features/confidence_scoring_service.dart' as _i116;
import '../services/features/exposure_calculation_service.dart' as _i758;
import '../services/features/health_analytics_service.dart' as _i380;
import '../services/features/health_data_export_service.dart' as _i327;
import '../services/features/health_questionnaire_service.dart' as _i896;
import '../services/features/lifetime_exposure_service.dart' as _i189;
import '../services/features/manual_correction_service.dart' as _i407;
import '../services/features/medical_examination_service.dart' as _i758;
import '../services/features/notification_service.dart' as _i491;
import '../services/features/offline_ai_service.dart' as _i797;
import '../services/features/qr_scanner_service.dart' as _i749;
import '../services/features/safety_briefing_service.dart' as _i974;
import '../services/features/screen_flash_service.dart' as _i673;
import '../services/features/session_service.dart' as _i669;
import '../services/features/smart_watch_service.dart' as _i123;
import '../services/features/supervisor_alert_service.dart' as _i173;
import '../services/features/timer_service.dart' as _i1001;
import '../services/features/tool_catalog_service.dart' as _i1053;
import '../services/features/tool_checkout_service.dart' as _i359;
import '../services/features/tool_condition_service.dart' as _i904;
import '../services/features/tool_cost_tracking_service.dart' as _i133;
import '../services/features/tool_inventory_service.dart' as _i125;
import '../services/features/tool_maintenance_service.dart' as _i459;
import '../services/features/tool_performance_service.dart' as _i1;
import '../services/features/tool_reservation_service.dart' as _i183;
import '../services/features/tool_service.dart' as _i814;
import '../services/features/tool_service_history_service.dart' as _i590;
import '../services/features/tool_sharing_service.dart' as _i220;
import '../services/features/tool_warranty_service.dart' as _i158;
import '../services/features/vibration_service.dart' as _i322;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    gh.lazySingleton<_i431.AccessibilityService>(
        () => _i431.AccessibilityService());
    gh.lazySingleton<_i918.FirebaseService>(() => _i918.FirebaseService());
    gh.lazySingleton<_i992.AuthSessionService>(
        () => _i992.AuthSessionService());
    gh.lazySingleton<_i1031.LocalizationService>(
        () => _i1031.LocalizationService());
    gh.lazySingleton<_i1028.AuthenticationService>(
        () => _i1028.AuthenticationService());
    gh.lazySingleton<_i312.ThemeService>(() => _i312.ThemeService());
    gh.lazySingleton<_i708.ConnectivityService>(
        () => _i708.ConnectivityService());
    gh.lazySingleton<_i814.ToolService>(() => _i814.ToolService());
    gh.lazySingleton<_i896.HealthQuestionnaireService>(
        () => _i896.HealthQuestionnaireService());
    gh.lazySingleton<_i459.ToolMaintenanceService>(
        () => _i459.ToolMaintenanceService());
    gh.lazySingleton<_i304.CameraService>(() => _i304.CameraService());
    gh.lazySingleton<_i669.SessionService>(() => _i669.SessionService());
    gh.lazySingleton<_i327.HealthDataExportService>(
        () => _i327.HealthDataExportService());
    gh.lazySingleton<_i1053.ToolCatalogService>(
        () => _i1053.ToolCatalogService());
    gh.lazySingleton<_i173.SupervisorAlertService>(
        () => _i173.SupervisorAlertService());
    gh.lazySingleton<_i590.ToolServiceHistoryService>(
        () => _i590.ToolServiceHistoryService());
    gh.lazySingleton<_i380.HealthAnalyticsService>(
        () => _i380.HealthAnalyticsService());
    gh.lazySingleton<_i322.VibrationService>(() => _i322.VibrationService());
    gh.lazySingleton<_i758.MedicalExaminationService>(
        () => _i758.MedicalExaminationService());
    gh.lazySingleton<_i123.SmartWatchService>(() => _i123.SmartWatchService());
    gh.lazySingleton<_i125.ToolInventoryService>(
        () => _i125.ToolInventoryService());
    gh.lazySingleton<_i673.ScreenFlashService>(
        () => _i673.ScreenFlashService());
    gh.lazySingleton<_i133.ToolCostTrackingService>(
        () => _i133.ToolCostTrackingService());
    gh.lazySingleton<_i904.ToolConditionService>(
        () => _i904.ToolConditionService());
    gh.lazySingleton<_i1.ToolPerformanceService>(
        () => _i1.ToolPerformanceService());
    gh.lazySingleton<_i749.QRScannerService>(() => _i749.QRScannerService());
    gh.lazySingleton<_i288.BackgroundTimerService>(
        () => _i288.BackgroundTimerService());
    gh.lazySingleton<_i359.ToolCheckoutService>(
        () => _i359.ToolCheckoutService());
    gh.lazySingleton<_i758.ExposureCalculationService>(
        () => _i758.ExposureCalculationService());
    gh.lazySingleton<_i778.AudioAlertService>(() => _i778.AudioAlertService());
    gh.lazySingleton<_i974.SafetyBriefingService>(
        () => _i974.SafetyBriefingService());
    gh.lazySingleton<_i491.NotificationService>(
        () => _i491.NotificationService());
    gh.lazySingleton<_i189.LifetimeExposureService>(
        () => _i189.LifetimeExposureService());
    gh.lazySingleton<_i158.ToolWarrantyService>(
        () => _i158.ToolWarrantyService());
    gh.lazySingleton<_i183.ToolReservationService>(
        () => _i183.ToolReservationService());
    gh.lazySingleton<_i220.ToolSharingService>(
        () => _i220.ToolSharingService());
    gh.lazySingleton<_i797.OfflineAIService>(() => _i797.OfflineAIService());
    gh.lazySingleton<_i689.AiService>(() => _i689.AiService());
    gh.lazySingleton<_i116.ConfidenceScoringService>(
        () => _i116.ConfidenceScoringService());
    gh.lazySingleton<_i407.ManualCorrectionService>(
        () => _i407.ManualCorrectionService());
    gh.lazySingleton<_i473.AdvancedAIService>(() => _i473.AdvancedAIService());
    gh.lazySingleton<_i1001.TimerService>(() => _i1001.TimerService());
    return this;
  }
}
