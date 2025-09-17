import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../../services/core/authentication_service.dart';
import '../../../../app/app.router.dart';
import '../../../../enums/user_role.dart';

class RegisterViewModel extends FormViewModel {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  // Form controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();

  // Form validation
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool get obscurePassword => _obscurePassword;
  bool get isPasswordVisible => !_obscurePassword;

  bool _obscureConfirmPassword = true;
  bool get obscureConfirmPassword => _obscureConfirmPassword;
  bool get isConfirmPasswordVisible => !_obscureConfirmPassword;

  UserRole _selectedRole = UserRole.worker;
  UserRole get selectedRole => _selectedRole;

  bool _agreeToTerms = false;
  bool get agreeToTerms => _agreeToTerms;

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _obscureConfirmPassword = !_obscureConfirmPassword;
    notifyListeners();
  }

  void setSelectedRole(UserRole? role) {
    if (role != null) {
      _selectedRole = role;
      notifyListeners();
    }
  }

  void setAgreeToTerms(bool value) {
    _agreeToTerms = value;
    notifyListeners();
  }

  // First name validation
  String? validateFirstName(String? value) {
    if (value == null || value.isEmpty) {
      return 'First name is required';
    }
    if (value.length < 2) {
      return 'First name must be at least 2 characters';
    }
    return null;
  }

  // Last name validation
  String? validateLastName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Last name is required';
    }
    if (value.length < 2) {
      return 'Last name must be at least 2 characters';
    }
    return null;
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
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return 'Password must contain uppercase, lowercase and numbers';
    }
    return null;
  }

  // Confirm password validation
  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Role validation
  String? validateRole(UserRole? value) {
    if (value == null) {
      return 'Please select a role';
    }
    return null;
  }

  // Company name validation (only for managers/admins)
  String? validateCompanyName(String? value) {
    if (_selectedRole == UserRole.manager || _selectedRole == UserRole.admin) {
      if (value == null || value.isEmpty) {
        return 'Company name is required for managers/admins';
      }
      if (value.length < 2) {
        return 'Company name must be at least 2 characters';
      }
    }
    return null;
  }

  // Register with email and password
  Future<void> register() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      _snackbarService.showSnackbar(
        message: 'Please agree to the Terms of Service and Privacy Policy',
      );
      return;
    }

    setBusy(true);

    try {
      final success = await _authService.registerUser(
        email: emailController.text.trim(),
        password: passwordController.text,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        role: _selectedRole,
        companyName: companyNameController.text.trim().isEmpty 
            ? null 
            : companyNameController.text.trim(),
      );

      if (success) {
        // Navigate to home screen
        await _navigationService.clearStackAndShow(Routes.homeView);
      }
    } finally {
      setBusy(false);
    }
  }

  // Navigate to login screen
  void navigateToLogin() {
    _navigationService.navigateTo(Routes.loginView);
  }

  // Sign up with Google
  Future<void> signUpWithGoogle() async {
    _snackbarService.showSnackbar(
      message: 'Google sign-in is not available in this version.',
    );
  }

  // Get role display name
  String getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.worker:
        return 'Construction Worker';
      case UserRole.manager:
        return 'Site Manager';
      case UserRole.admin:
        return 'Company Admin';
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    companyNameController.dispose();
    super.dispose();
  }
}