import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'settings_viewmodel.dart';

class SettingsView extends StackedView<SettingsViewModel> {
  const SettingsView({super.key});

  @override
  Widget builder(BuildContext context, SettingsViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            // App Logo
            Image.asset(
              'assets/images/App_logo.png',
              height: 28,
              width: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('Settings'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Section
                _buildProfileSection(context, viewModel),
                
                const SizedBox(height: 24),
                
                // Notification Settings
                _buildNotificationSection(context, viewModel),
                
                const SizedBox(height: 24),
                
                // Safety Settings
                _buildSafetySection(context, viewModel),
                
                const SizedBox(height: 24),
                
                // App Settings
                _buildAppSection(context, viewModel),
                
                const SizedBox(height: 24),
                
                // Data & Privacy
                _buildDataSection(context, viewModel),
                
                const SizedBox(height: 24),
                
                // About & Support
                _buildAboutSection(context, viewModel),
                
                const SizedBox(height: 32),
                
                // Sign Out Button
                _buildSignOutButton(context, viewModel),
              ],
            ),
    );
  }

  Widget _buildProfileSection(BuildContext context, SettingsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  viewModel.currentUser?.initials ?? 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(viewModel.currentUser?.fullName ?? 'User'),
              subtitle: Text(viewModel.currentUser?.email ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => viewModel.navigateToProfile(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection(BuildContext context, SettingsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow Notifications'),
              subtitle: const Text('Enable all app notifications'),
              value: viewModel.allowNotifications,
              onChanged: viewModel.toggleNotifications,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Safety Alerts'),
              subtitle: const Text('Critical safety warnings and alerts'),
              value: viewModel.safetyAlerts,
              onChanged: viewModel.allowNotifications ? viewModel.toggleSafetyAlerts : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Break Reminders'),
              subtitle: const Text('Reminders to take breaks'),
              value: viewModel.breakReminders,
              onChanged: viewModel.allowNotifications ? viewModel.toggleBreakReminders : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Reports'),
              subtitle: const Text('Daily exposure summary reports'),
              value: viewModel.dailyReports,
              onChanged: viewModel.allowNotifications ? viewModel.toggleDailyReports : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection(BuildContext context, SettingsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Safety Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Exposure Limit'),
              subtitle: Text('${viewModel.dailyExposureLimit} minutes (${(viewModel.dailyExposureLimit / 60).toStringAsFixed(1)} hours)'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showExposureLimitDialog(context, viewModel),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Warning Threshold'),
              subtitle: Text('${viewModel.warningThreshold}% of daily limit'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showWarningThresholdDialog(context, viewModel),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Break Interval'),
              subtitle: Text('Every ${viewModel.breakInterval} minutes'),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _showBreakIntervalDialog(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppSection(BuildContext context, SettingsViewModel viewModel) {
    print("🔧 Building App Section - Theme: ${viewModel.currentThemeName}, Language: ${viewModel.currentLanguage}");
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Theme Settings
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Theme'),
              subtitle: Text(viewModel.currentThemeName),
              leading: Icon(viewModel.currentThemeIcon),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Light Mode Button
                  IconButton(
                    icon: Icon(
                      Icons.light_mode,
                      color: viewModel.isLightMode
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: viewModel.setLightMode,
                    tooltip: 'Light Mode',
                  ),
                  // Dark Mode Button
                  IconButton(
                    icon: Icon(
                      Icons.dark_mode,
                      color: viewModel.isDarkMode
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: viewModel.setDarkMode,
                    tooltip: 'Dark Mode',
                  ),
                  // System Mode Button
                  IconButton(
                    icon: Icon(
                      Icons.brightness_auto,
                      color: viewModel.isSystemMode
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: viewModel.setSystemMode,
                    tooltip: 'System Mode',
                  ),
                ],
              ),
              onTap: viewModel.toggleTheme,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Language'),
              subtitle: Text(viewModel.currentLanguage),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // English Button
                  IconButton(
                    icon: Text(
                      'EN',
                      style: TextStyle(
                        fontWeight: viewModel.currentLanguageCode == 'en'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: viewModel.currentLanguageCode == 'en'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onPressed: viewModel.setToEnglish,
                    tooltip: 'English',
                  ),
                  // Spanish Button
                  IconButton(
                    icon: Text(
                      'ES',
                      style: TextStyle(
                        fontWeight: viewModel.currentLanguageCode == 'es'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: viewModel.currentLanguageCode == 'es'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onPressed: viewModel.setToSpanish,
                    tooltip: 'Español',
                  ),
                  // French Button
                  IconButton(
                    icon: Text(
                      'FR',
                      style: TextStyle(
                        fontWeight: viewModel.currentLanguageCode == 'fr'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: viewModel.currentLanguageCode == 'fr'
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onPressed: viewModel.setToFrench,
                    tooltip: 'Français',
                  ),
                ],
              ),
              onTap: () => _showLanguageDialog(context, viewModel),
            ),
            const SizedBox(height: 16),
            
            // Accessibility Settings
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Accessibility'),
              subtitle: const Text('Text scaling, contrast, animations'),
              leading: const Icon(Icons.accessibility),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToAccessibility(context),
            ),
            
            const SizedBox(height: 16),
            
            // Help & Support
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Help & Support'),
              subtitle: const Text('FAQ, tutorials, contact support'),
              leading: const Icon(Icons.help_outline),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToHelp(context),
            ),
            
            const SizedBox(height: 16),
            
            // Send Feedback
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send Feedback'),
              subtitle: const Text('Report bugs, suggest features'),
              leading: const Icon(Icons.feedback),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigateToFeedback(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection(BuildContext context, SettingsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data & Privacy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Account Management'),
              subtitle: const Text('Manage account security and data'),
              leading: Icon(Icons.manage_accounts),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => viewModel.navigateToAccountManagement(),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Export Settings'),
              subtitle: const Text('Save your settings to a file'),
              leading: Icon(Icons.file_download),
              onTap: () => viewModel.exportSettings(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Import Settings'),
              subtitle: const Text('Load settings from a file'),
              leading: Icon(Icons.file_upload),
              onTap: () => viewModel.importSettings(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clear Cache'),
              subtitle: const Text('Free up storage space'),
              leading: Icon(Icons.storage),
              onTap: () => viewModel.clearCache(),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reset to Defaults'),
              subtitle: const Text('Restore all settings to default values'),
              leading: Icon(Icons.restore),
              onTap: () => _showResetDialog(context, viewModel),
            ),
            const Divider(),
            
            // Performance Monitoring
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Performance Monitor'),
              subtitle: const Text('Monitor app performance and resources'),
              leading: Icon(Icons.speed),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToPerformance(context),
            ),
            
            // Battery Optimization
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Battery Optimization'),
              subtitle: const Text('Optimize battery usage and power saving'),
              leading: Icon(Icons.battery_std),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToBatteryOptimization(context),
            ),
            
            // Data Usage Optimization
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Usage'),
              subtitle: const Text('Monitor and optimize data usage'),
              leading: Icon(Icons.data_usage),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToDataUsage(context),
            ),
            
            // Offline Mode
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Offline Mode'),
              subtitle: const Text('Manage offline functionality and sync'),
              leading: Icon(Icons.cloud_off),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => _navigateToOfflineMode(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, SettingsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About & Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('About'),
              subtitle: const Text('App version and information'),
              leading: Icon(Icons.info),
              onTap: () => viewModel.showAboutDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Help & Support'),
              subtitle: const Text('Get help using the app'),
              leading: Icon(Icons.help),
              onTap: () => _showHelpDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Privacy Policy'),
              subtitle: const Text('Read our privacy policy'),
              leading: Icon(Icons.privacy_tip),
              onTap: () => _showPrivacyDialog(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Terms of Service'),
              subtitle: const Text('Read our terms of service'),
              leading: Icon(Icons.description),
              onTap: () => _showTermsDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context, SettingsViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showSignOutDialog(context, viewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
      ),
    );
  }

  Future<void> _showExposureLimitDialog(BuildContext context, SettingsViewModel viewModel) async {
    final controller = TextEditingController(text: viewModel.dailyExposureLimit.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Daily Exposure Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set the maximum daily exposure in minutes (HSE recommends 360 minutes/6 hours)'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0 && value <= 480) {
                viewModel.setDailyExposureLimit(value);
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarningThresholdDialog(BuildContext context, SettingsViewModel viewModel) async {
    final controller = TextEditingController(text: viewModel.warningThreshold.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Warning Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set the percentage of daily limit that triggers warnings'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Percentage',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 50 && value <= 100) {
                viewModel.setWarningThreshold(value);
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBreakIntervalDialog(BuildContext context, SettingsViewModel viewModel) async {
    final controller = TextEditingController(text: viewModel.breakInterval.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Break Interval'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set how often to remind users to take breaks'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minutes',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 15 && value <= 120) {
                viewModel.setBreakInterval(value);
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context, SettingsViewModel viewModel) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: viewModel.availableLanguages.entries.map((entry) => RadioListTile<String>(
            title: Text(entry.value),
            value: entry.key,
            groupValue: viewModel.currentLanguageCode,
            onChanged: (value) {
              if (value != null) {
                viewModel.setLanguage(value);
                Navigator.pop(context);
              }
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog(BuildContext context, SettingsViewModel viewModel) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Settings'),
        content: Text('Are you sure you want to reset all settings to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.resetToDefaults();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSignOutDialog(BuildContext context, SettingsViewModel viewModel) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.signOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help with Vibe Guard?'),
            SizedBox(height: 16),
            Text('• Visit our online documentation'),
            Text('• Email: support@vibeguard.com'),
            Text('• Phone: +1 (555) 123-4567'),
            Text('• Available: Mon-Fri 9AM-5PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(
            'Vibe Guard Privacy Policy\n\n'
            'We collect and use your data to provide safety monitoring services. '
            'Your session data is stored securely and used only for safety analysis. '
            'We do not share your personal data with third parties without consent.\n\n'
            'For the complete privacy policy, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Text(
            'Vibe Guard Terms of Service\n\n'
            'By using this app, you agree to follow safety guidelines and use the '
            'app as intended for workplace safety monitoring. The app provides '
            'estimates and should not replace professional safety equipment.\n\n'
            'For complete terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Navigation methods for new features
  void _navigateToAccessibility(BuildContext context) {
    // Navigate to accessibility settings
    Navigator.pushNamed(context, '/accessibility');
  }

  void _navigateToHelp(BuildContext context) {
    Navigator.pushNamed(context, '/help');
  }

  void _navigateToFeedback(BuildContext context) {
    Navigator.pushNamed(context, '/feedback');
  }

  void _navigateToPerformance(BuildContext context) {
    Navigator.pushNamed(context, '/performance');
  }

  void _navigateToBatteryOptimization(BuildContext context) {
    Navigator.pushNamed(context, '/battery-optimization');
  }

  void _navigateToDataUsage(BuildContext context) {
    Navigator.pushNamed(context, '/data-usage');
  }

  void _navigateToOfflineMode(BuildContext context) {
    Navigator.pushNamed(context, '/offline-mode');
  }

  @override
  SettingsViewModel viewModelBuilder(BuildContext context) => SettingsViewModel();
}
