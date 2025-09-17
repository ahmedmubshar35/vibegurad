import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';
import '../../../../services/core/authentication_service.dart';
import '../../../../services/core/auth_session_service.dart';
import '../../../../app/app.router.dart';

class AccountManagementView extends StatefulWidget {
  const AccountManagementView({super.key});

  @override
  State<AccountManagementView> createState() => _AccountManagementViewState();
}

class _AccountManagementViewState extends State<AccountManagementView> {
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  final AuthSessionService _sessionService = GetIt.instance<AuthSessionService>();
  final NavigationService _navigationService = GetIt.instance<NavigationService>();
  final DialogService _dialogService = GetIt.instance<DialogService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
  
  // Show deactivate account dialog
  Future<void> _showDeactivateDialog() async {
    final response = await _dialogService.showConfirmationDialog(
      title: 'Deactivate Account',
      description: 'Are you sure you want to deactivate your account? You can reactivate it by logging in again.',
      confirmationTitle: 'Deactivate',
      cancelTitle: 'Cancel',
      barrierDismissible: true,
    );
    
    if (response?.confirmed == true) {
      setState(() => _isLoading = true);
      
      final success = await _authService.deactivateAccount();
      
      setState(() => _isLoading = false);
      
      if (success) {
        await _navigationService.clearStackAndShow(Routes.loginView);
      }
    }
  }
  
  // Show delete account dialog
  Future<void> _showDeleteDialog() async {
    // First confirmation
    final firstConfirmation = await _dialogService.showConfirmationDialog(
      title: 'Delete Account Permanently',
      description: 'WARNING: This action cannot be undone. All your data will be permanently deleted.',
      confirmationTitle: 'Continue',
      cancelTitle: 'Cancel',
      barrierDismissible: true,
    );
    
    if (firstConfirmation?.confirmed != true) return;
    
    // Show password input dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your password to confirm account deletion.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _passwordController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_passwordController.text.isEmpty) {
                  _snackbarService.showSnackbar(
                    message: 'Please enter your password',
                  );
                  return;
                }
                
                Navigator.of(context).pop();
                
                setState(() => _isLoading = true);
                
                final success = await _authService.deleteAccount(
                  password: _passwordController.text,
                );
                
                _passwordController.clear();
                setState(() => _isLoading = false);
                
                if (success) {
                  await _navigationService.clearStackAndShow(Routes.loginView);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }
  
  // Clear session data
  Future<void> _clearSessionData() async {
    await _sessionService.clearRememberMe();
    _snackbarService.showSnackbar(
      message: 'Session data cleared',
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Account Actions Section
                Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Account Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      
                      // Clear Session Data
                      ListTile(
                        leading: const Icon(Icons.cleaning_services),
                        title: const Text('Clear Session Data'),
                        subtitle: const Text('Remove saved login information'),
                        onTap: _clearSessionData,
                      ),
                      
                      // Session Settings
                      ListTile(
                        leading: const Icon(Icons.timer),
                        title: const Text('Session Timeout'),
                        subtitle: const Text('Configure auto-logout time'),
                        trailing: const Text('30 min'),
                        onTap: () {
                          _snackbarService.showSnackbar(
                            message: 'Session timeout configuration coming soon',
                          );
                        },
                      ),
                      
                      // Export Data
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('Export My Data'),
                        subtitle: const Text('Download all your personal data'),
                        onTap: () {
                          _snackbarService.showSnackbar(
                            message: 'Data export feature coming soon',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Danger Zone Section
                Card(
                  elevation: 2,
                  color: Colors.red.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: Colors.red),
                      
                      // Deactivate Account
                      ListTile(
                        leading: const Icon(Icons.pause_circle, color: Colors.orange),
                        title: const Text(
                          'Deactivate Account',
                          style: TextStyle(color: Colors.orange),
                        ),
                        subtitle: const Text(
                          'Temporarily disable your account',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: _showDeactivateDialog,
                      ),
                      
                      // Delete Account
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(color: Colors.red),
                        ),
                        subtitle: const Text(
                          'Permanently delete your account and all data',
                          style: TextStyle(fontSize: 12),
                        ),
                        onTap: _showDeleteDialog,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Information Card
                Card(
                  elevation: 1,
                  color: Colors.blue.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Important Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Deactivating your account will hide your profile and stop all notifications.\n'
                          '• You can reactivate your account anytime by logging in.\n'
                          '• Deleting your account is permanent and cannot be undone.\n'
                          '• All your data, including health records and tool history, will be deleted.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}