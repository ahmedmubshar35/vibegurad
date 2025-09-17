class AppConfig {
  // App Information
  static const String appName = 'VibeGuard';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Construction Worker Health & Safety Platform';
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.vibeguard.com';
  static const int apiTimeoutSeconds = 30;
  
  // Timer Configuration
  static const int maxExposureTimeMinutes = 480; // 8 hours
  static const int restPeriodMinutes = 15;
  static const int warningThresholdMinutes = 30;
  
  // Camera Configuration
  static const double minImageQuality = 0.8;
  static const int maxImageSize = 1024;
  
  // Notification Configuration
  static const String notificationChannelId = 'vibe_guard_alerts';
  static const String notificationChannelName = 'Safety Alerts';
  static const String notificationChannelDescription = 'Important safety alerts and warnings';
  
  // Database Configuration
  static const String usersCollection = 'users';
  static const String toolsCollection = 'tools';
  static const String sessionsCollection = 'sessions';
  static const String exposuresCollection = 'exposures';
  static const String companiesCollection = 'companies';
  
  // Feature Flags
  static const bool enableToolRecognition = true;
  static const bool enableGpsTracking = true;
  static const bool enableOfflineMode = true;
  static const bool enablePushNotifications = true;
  
  // Safety Thresholds (OSHA Guidelines)
  static const Map<String, double> toolVibrationLevels = {
    'drill': 2.5, // m/s²
    'grinder': 4.0,
    'jackhammer': 8.0,
    'saw': 3.5,
    'hammer': 6.0,
  };
  
  // Exposure Limits (OSHA A(8) values)
  static const Map<String, int> toolExposureLimits = {
    'drill': 480, // minutes per day
    'grinder': 300,
    'jackhammer': 150,
    'saw': 400,
    'hammer': 200,
  };
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 8.0;
  static const double defaultElevation = 2.0;
  
  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
}
