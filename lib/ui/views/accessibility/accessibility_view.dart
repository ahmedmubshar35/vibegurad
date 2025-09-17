import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'accessibility_viewmodel.dart';

class AccessibilityView extends StackedView<AccessibilityViewModel> {
  const AccessibilityView({super.key});

  @override
  Widget builder(BuildContext context, AccessibilityViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Scaling
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Text Scaling',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Current Scale: ${viewModel.currentTextScaleName}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          ...viewModel.availableTextScales.entries.map((scale) => 
                            RadioListTile<String>(
                              title: Text(scale.key),
                              subtitle: Text('${(scale.value * 100).toInt()}%'),
                              value: scale.key,
                              groupValue: viewModel.currentTextScaleName,
                              onChanged: (value) => viewModel.setTextScale(value!),
                            ),
                          ).toList(),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // High Contrast Mode
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'High Contrast Mode',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable High Contrast'),
                            subtitle: const Text('Increases contrast for better visibility'),
                            value: viewModel.highContrastMode,
                            onChanged: viewModel.setHighContrastMode,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Reduced Animations
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reduced Animations',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Reduce Animations'),
                            subtitle: const Text('Minimizes motion for better accessibility'),
                            value: viewModel.reduceAnimations,
                            onChanged: viewModel.setReduceAnimations,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Screen Reader Support
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Screen Reader Support',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Enable Screen Reader'),
                            subtitle: const Text('Optimizes app for screen readers'),
                            value: viewModel.screenReaderEnabled,
                            onChanged: viewModel.setScreenReaderEnabled,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Accessibility Tips
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accessibility Tips',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '• Use larger text sizes for better readability\n'
                            '• Enable high contrast for outdoor visibility\n'
                            '• Reduce animations if you experience motion sensitivity\n'
                            '• Screen reader support helps with navigation\n'
                            '• All settings are automatically saved',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  AccessibilityViewModel viewModelBuilder(BuildContext context) => AccessibilityViewModel();
}









