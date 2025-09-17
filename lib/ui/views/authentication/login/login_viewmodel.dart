import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/core/authentication_service.dart';
import '../../../../services/core/auth_session_service.dart';
import '../../../../app/app.router.dart';

class LoginViewModel extends BaseViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final AuthSessionService _sessionService = GetIt.instance<AuthSessionService>();

  // Form controllers
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Form validation
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;
  
  bool _rememberMe = false;
  bool get rememberMe => _rememberMe;
  
  LoginViewModel() {
    _loadRememberedUser();
  }
  
  // Load remembered user email
  Future<void> _loadRememberedUser() async {
    final remembered = await _sessionService.getRememberedUser();
    if (remembered['remember'] == true && remembered['email'] != null) {
      emailController.text = remembered['email'];
      _rememberMe = true;
      notifyListeners();
    }
  }
  
  // Set remember me preference
  void setRememberMe(bool? value) {
    _rememberMe = value ?? false;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // Email validation
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Password validation
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Sign in with email and password
  Future<void> signIn() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setBusy(true);

    try {
      final success = await _authService.signInUser(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (success) {
        // Save remember me preference
        await _sessionService.saveRememberMe(
          emailController.text.trim(),
          _rememberMe,
        );
        
        // Start session monitoring
        _sessionService.updateActivity();
        
        // Navigate to home screen
        await _navigationService.clearStackAndShow(Routes.homeView);
      }
    } finally {
      setBusy(false);
    }
  }

  // Navigate to register screen
  void navigateToRegister() {
    _navigationService.navigateTo(Routes.registerView);
  }

  // Navigate to forgot password screen
  void resetPassword() {
    _navigationService.navigateTo(Routes.forgotPasswordView);
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    _snackbarService.showSnackbar(
      message: 'Google sign-in is not available in this version.',
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
