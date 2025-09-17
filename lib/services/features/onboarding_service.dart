import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stacked/stacked.dart';

@lazySingleton
class OnboardingService with ListenableServiceMixin {
  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _lastOnboardingVersionKey = 'last_onboarding_version';
  
  SharedPreferences? _prefs;
  bool _isOnboardingCompleted = false;
  String _currentVersion = '1.0.0';
  
  bool get isOnboardingCompleted => _isOnboardingCompleted;
  String get currentVersion => _currentVersion;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadOnboardingStatus();
  }
  
  Future<void> _loadOnboardingStatus() async {
    _isOnboardingCompleted = _prefs?.getBool(_onboardingCompletedKey) ?? false;
    notifyListeners();
  }
  
  Future<void> completeOnboarding() async {
    _isOnboardingCompleted = true;
    await _prefs?.setBool(_onboardingCompletedKey, true);
    await _prefs?.setString(_lastOnboardingVersionKey, _currentVersion);
    notifyListeners();
  }
  
  Future<void> resetOnboarding() async {
    _isOnboardingCompleted = false;
    await _prefs?.remove(_onboardingCompletedKey);
    await _prefs?.remove(_lastOnboardingVersionKey);
    notifyListeners();
  }
  
  bool shouldShowOnboarding() {
    if (!_isOnboardingCompleted) return true;
    
    final lastVersion = _prefs?.getString(_lastOnboardingVersionKey) ?? '';
    return lastVersion != _currentVersion;
  }
  
  // Onboarding steps data
  List<OnboardingStep> get onboardingSteps => [
    OnboardingStep(
      title: 'Welcome to VibeGuard',
      description: 'Protect your hands from vibration-related injuries with AI-powered tool recognition and real-time exposure monitoring.',
      imagePath: 'assets/images/onboarding/welcome.png',
      icon: Icons.waving_hand,
    ),
    OnboardingStep(
      title: 'AI Tool Recognition',
      description: 'Simply take a photo of your power tool and our AI will instantly identify it and calculate safe usage limits.',
      imagePath: 'assets/images/onboarding/tool_recognition.png',
      icon: Icons.camera_alt,
    ),
    OnboardingStep(
      title: 'Smart Timer & Alerts',
      description: 'Get real-time alerts when approaching exposure limits. The app enforces mandatory rest periods to protect your health.',
      imagePath: 'assets/images/onboarding/timer.png',
      icon: Icons.timer,
    ),
    OnboardingStep(
      title: 'Health Tracking',
      description: 'Track your daily, weekly, and monthly vibration exposure. Generate reports for your safety manager.',
      imagePath: 'assets/images/onboarding/health_tracking.png',
      icon: Icons.health_and_safety,
    ),
    OnboardingStep(
      title: 'Offline Capability',
      description: 'Works even without internet connection. Your data syncs automatically when connection is restored.',
      imagePath: 'assets/images/onboarding/offline.png',
      icon: Icons.cloud_off,
    ),
    OnboardingStep(
      title: 'Ready to Start',
      description: 'You\'re all set! Start by scanning a tool or checking your exposure history.',
      imagePath: 'assets/images/onboarding/ready.png',
      icon: Icons.check_circle,
    ),
  ];
}

class OnboardingStep {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;
  
  OnboardingStep({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
  });
}

