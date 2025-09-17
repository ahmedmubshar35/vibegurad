import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../services/core/authentication_service.dart';
import '../../../app/app.router.dart';

class SplashViewModel extends BaseViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();

  // Initialize the splash screen
  void initialize() {
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Simulate initialization time
      await Future.delayed(const Duration(seconds: 2));
      
      // Check if user is already logged in
      final currentUser = _authService.currentUser;
      
      if (currentUser != null) {
        // User is logged in, navigate to home
        await _navigationService.navigateTo(Routes.homeView);
      } else {
        // User is not logged in, navigate to login
        await _navigationService.navigateTo(Routes.loginView);
      }
    } catch (e) {
      // On error, navigate to login
      await _navigationService.navigateTo(Routes.loginView);
    }
  }
}
