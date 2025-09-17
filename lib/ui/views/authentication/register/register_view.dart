import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'register_viewmodel.dart';
import '../../../../enums/user_role.dart';

class RegisterView extends StackedView<RegisterViewModel> {
  const RegisterView({super.key});

  @override
  Widget builder(BuildContext context, RegisterViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: viewModel.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header
                Text(
                  'Join VibeGuard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Protect yourself from HAVS with smart monitoring',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // First Name Field
                TextFormField(
                  controller: viewModel.firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'First Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: viewModel.validateFirstName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Last Name Field
                TextFormField(
                  controller: viewModel.lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Last Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: viewModel.validateLastName,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: viewModel.emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: viewModel.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(
                  controller: viewModel.passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        viewModel.isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: viewModel.togglePasswordVisibility,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: viewModel.validatePassword,
                  obscureText: !viewModel.isPasswordVisible,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(
                  controller: viewModel.confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        viewModel.isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: viewModel.toggleConfirmPasswordVisibility,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: viewModel.validateConfirmPassword,
                  obscureText: !viewModel.isConfirmPasswordVisible,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Role Selection
                DropdownButtonFormField<UserRole>(
                  value: viewModel.selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: viewModel.setSelectedRole,
                  validator: viewModel.validateRole,
                ),
                const SizedBox(height: 16),

                // Company Name Field (optional for workers)
                if (viewModel.selectedRole != UserRole.worker) ...[
                  TextFormField(
                    controller: viewModel.companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: viewModel.validateCompanyName,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Terms and Conditions Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: viewModel.agreeToTerms,
                      onChanged: (value) => viewModel.setAgreeToTerms(value ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            const TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: viewModel.isBusy ? null : viewModel.register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: viewModel.isBusy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: viewModel.navigateToLogin,
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  RegisterViewModel viewModelBuilder(BuildContext context) => RegisterViewModel();
}