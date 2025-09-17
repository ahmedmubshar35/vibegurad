import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/core/authentication_service.dart';

class ForgotPasswordViewModel extends FormViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // Form controllers
  final TextEditingController emailController = TextEditingController();
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _emailSent = false;
  bool get emailSent => _emailSent;

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

  // Send reset password email
  Future<void> sendResetEmail() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    setBusy(true);

    try {
      final success = await _authService.resetPassword(emailController.text.trim());
      
      if (success) {
        _emailSent = true;
        notifyListeners();
      }
    } finally {
      setBusy(false);
    }
  }

  // Navigate back to login
  void navigateToLogin() {
    _navigationService.back();
  }

  // Resend email
  Future<void> resendEmail() async {
    _emailSent = false;
    notifyListeners();
    await sendResetEmail();
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}