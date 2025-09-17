import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/onboarding_service.dart';

class OnboardingViewModel extends BaseViewModel {
  final _onboardingService = locator<OnboardingService>();
  final _navigationService = locator<NavigationService>();
  
  late PageController _pageController;
  int _currentPage = 0;
  
  PageController get pageController => _pageController;
  int get currentPage => _currentPage;
  List<OnboardingStep> get onboardingSteps => _onboardingService.onboardingSteps;
  
  OnboardingViewModel() {
    _pageController = PageController();
  }
  
  void onPageChanged(int page) {
    _currentPage = page;
    notifyListeners();
  }
  
  void nextPage() {
    if (_currentPage < onboardingSteps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  void previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  Future<void> completeOnboarding() async {
    setBusy(true);
    try {
      await _onboardingService.completeOnboarding();
      _navigationService.clearStackAndShow('/home');
    } catch (e) {
      // Handle error
    } finally {
      setBusy(false);
    }
  }
  
  Future<void> skipOnboarding() async {
    setBusy(true);
    try {
      await _onboardingService.completeOnboarding();
      _navigationService.clearStackAndShow('/home');
    } catch (e) {
      // Handle error
    } finally {
      setBusy(false);
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}