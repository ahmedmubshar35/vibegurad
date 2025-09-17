import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'splash_viewmodel.dart';

class SplashView extends StackedView<SplashViewModel> {
  const SplashView({super.key});

  @override
  void onViewModelReady(SplashViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.initialize();
  }

  @override
  Widget builder(BuildContext context, SplashViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Image.asset(
              'assets/images/App_logo.png',
              height: 120,
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              'VibeGuard',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 8),
            
            // Tagline
            Text(
              'Construction Worker Health & Safety',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            
            // Loading Text
            Text(
              'Initializing...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  SplashViewModel viewModelBuilder(BuildContext context) => SplashViewModel();
}
