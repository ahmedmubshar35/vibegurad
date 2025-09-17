import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/onboarding_service.dart';
import 'onboarding_viewmodel.dart';

class OnboardingView extends StatelessWidget {
  const OnboardingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<OnboardingViewModel>.reactive(
      viewModelBuilder: () => OnboardingViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          body: SafeArea(
            child: PageView.builder(
              controller: viewModel.pageController,
              onPageChanged: viewModel.onPageChanged,
              itemCount: viewModel.onboardingSteps.length,
              itemBuilder: (context, index) {
                final step = viewModel.onboardingSteps[index];
                return _buildOnboardingPage(context, step, index, viewModel);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnboardingPage(
    BuildContext context,
    OnboardingStep step,
    int index,
    OnboardingViewModel viewModel,
  ) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              viewModel.onboardingSteps.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Title
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Description
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // Action buttons
          Row(
            children: [
              if (index > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: viewModel.previousPage,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: index == viewModel.onboardingSteps.length - 1
                      ? viewModel.completeOnboarding
                      : viewModel.nextPage,
                  child: Text(
                    index == viewModel.onboardingSteps.length - 1
                        ? 'Get Started'
                        : 'Next',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Skip button
          TextButton(
            onPressed: viewModel.skipOnboarding,
            child: Text(
              'Skip Tutorial',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}