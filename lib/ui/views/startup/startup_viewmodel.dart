import 'package:stacked/stacked.dart';
import 'package:get_it/get_it.dart';

import '../../../services/core/authentication_service.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.router.dart';

class StartupViewModel extends BaseViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();

  Future<void> initialize() async {
    setBusy(true);
    
    try {
      // Wait a bit for the UI to show
      await Future.delayed(const Duration(seconds: 2));
      
      // Check authentication status
      if (_authService.isAuthenticated && _authService.currentUser != null) {
        // User is logged in and has user data, navigate to home
        print('✅ User is authenticated, navigating to home');
        await _navigationService.navigateTo(Routes.homeView);
      } else {
        // User is not logged in, navigate to login
        print('❌ User is not authenticated, navigating to login');
        await _navigationService.navigateTo(Routes.loginView);
      }
    } catch (e) {
      print('❌ Error during startup: $e');
      // If there's an error, navigate to login
      await _navigationService.navigateTo(Routes.loginView);
    } finally {
      setBusy(false);
    }
  }
}
