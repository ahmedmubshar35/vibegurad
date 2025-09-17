import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'forgot_password_viewmodel.dart';

class ForgotPasswordView extends StackedView<ForgotPasswordViewModel> {
  const ForgotPasswordView({super.key});

  @override
  Widget builder(BuildContext context, ForgotPasswordViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: viewModel.navigateToLogin,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: viewModel.emailSent 
              ? _buildEmailSentScreen(context, viewModel)
              : _buildResetForm(context, viewModel),
        ),
      ),
    );
  }

  Widget _buildResetForm(BuildContext context, ForgotPasswordViewModel viewModel) {
    return Form(
      key: viewModel.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Icon
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_reset,
              size: 50,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Title
          Text(
            'Reset Password',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            'Enter your email address and we\'ll send you a link to reset your password.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Email Field
          TextFormField(
            controller: viewModel.emailController,
            keyboardType: TextInputType.emailAddress,
            validator: viewModel.validateEmail,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Send Reset Link Button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: viewModel.isBusy ? null : viewModel.sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: viewModel.isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send Reset Link',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Back to Login
          TextButton(
            onPressed: viewModel.navigateToLogin,
            child: Text(
              'Back to Login',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSentScreen(BuildContext context, ForgotPasswordViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        
        // Success Icon
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read,
            size: 50,
            color: Colors.green,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Title
        Text(
          'Email Sent!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 16),
        
        // Description
        Text(
          'We\'ve sent a password reset link to ${viewModel.emailController.text}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Check your email and follow the instructions to reset your password.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 40),
        
        // Resend Email Button
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: viewModel.isBusy ? null : viewModel.resendEmail,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: viewModel.isBusy
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Resend Email',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Back to Login
        TextButton(
          onPressed: viewModel.navigateToLogin,
          child: Text(
            'Back to Login',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  ForgotPasswordViewModel viewModelBuilder(BuildContext context) => ForgotPasswordViewModel();
}