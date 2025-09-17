import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'profile_viewmodel.dart';

class ProfileView extends StackedView<ProfileViewModel> {
  const ProfileView({super.key});

  @override
  Widget builder(BuildContext context, ProfileViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (viewModel.isEditing) ...[
            TextButton(
              onPressed: viewModel.toggleEditing,
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: viewModel.saveProfile,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: viewModel.toggleEditing,
            ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.refreshProfile,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Profile Header
                  _buildProfileHeader(context, viewModel),
                  
                  const SizedBox(height: 24),
                  
                  // Health Metrics
                  _buildHealthMetrics(context, viewModel),
                  
                  const SizedBox(height: 24),
                  
                  // Safety Insights
                  _buildSafetyInsights(context, viewModel),
                  
                  const SizedBox(height: 24),
                  
                  // Achievements
                  _buildAchievements(context, viewModel),
                  
                  const SizedBox(height: 24),
                  
                  // Profile Information
                  _buildProfileInformation(context, viewModel),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, ProfileViewModel viewModel) {
    final user = viewModel.currentUser;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user?.initials ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Name and Role
            Text(
              user?.fullName ?? 'User',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 4),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                user?.role.name.toUpperCase() ?? 'WORKER',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              user?.companyName ?? 'No Company',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetrics(BuildContext context, ProfileViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Health Metrics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Today's Exposure
            _buildHealthMetricRow(
              context,
              'Today\'s Exposure',
              '${viewModel.totalExposureToday} min',
              viewModel.totalExposureToday / 360, // Out of 6 hours
              viewModel.totalExposureToday > 360 ? Colors.red : 
              viewModel.totalExposureToday > 280 ? Colors.orange : Colors.green,
            ),
            
            const SizedBox(height: 16),
            
            // Weekly Exposure
            _buildHealthMetricRow(
              context,
              'Weekly Exposure',
              '${(viewModel.totalExposureWeek / 60).toStringAsFixed(1)} hours',
              (viewModel.totalExposureWeek / 60) / 30, // Out of 30 hours per week
              Colors.blue,
            ),
            
            const SizedBox(height: 16),
            
            // Safety Score
            _buildHealthMetricRow(
              context,
              'Safety Score',
              '${viewModel.safetyScore}%',
              viewModel.safetyScore / 100,
              viewModel.safetyScore >= 80 ? Colors.green : 
              viewModel.safetyScore >= 60 ? Colors.orange : Colors.red,
            ),
            
            const SizedBox(height: 16),
            
            // Risk Level
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Risk Level',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: viewModel.getRiskLevelColor(),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    viewModel.riskLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthMetricRow(
    BuildContext context,
    String label,
    String value,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.withOpacity(0.3),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildSafetyInsights(BuildContext context, ProfileViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Safety Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommendation',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.getHealthRecommendation(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Quick Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    context,
                    'Total Sessions',
                    '${viewModel.totalSessions}',
                    Icons.timer,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickStat(
                    context,
                    'Avg. Session',
                    '${viewModel.averageSessionLength.round()} min',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements(BuildContext context, ProfileViewModel viewModel) {
    final achievements = viewModel.getRecentAchievements();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: achievements.map((achievement) => Chip(
                label: Text(achievement),
                avatar: const Icon(Icons.star, size: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInformation(BuildContext context, ProfileViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // First Name
            _buildProfileField(
              context,
              'First Name',
              viewModel.firstNameController,
              viewModel.isEditing,
            ),
            
            const SizedBox(height: 16),
            
            // Last Name
            _buildProfileField(
              context,
              'Last Name',
              viewModel.lastNameController,
              viewModel.isEditing,
            ),
            
            const SizedBox(height: 16),
            
            // Email (readonly)
            _buildProfileField(
              context,
              'Email',
              TextEditingController(text: viewModel.currentUser?.email ?? ''),
              false,
            ),
            
            const SizedBox(height: 16),
            
            // Phone Number
            _buildProfileField(
              context,
              'Phone Number',
              viewModel.phoneController,
              viewModel.isEditing,
            ),
            
            const SizedBox(height: 16),
            
            // Company Name
            _buildProfileField(
              context,
              'Company',
              viewModel.companyNameController,
              viewModel.isEditing,
            ),
            
            if (viewModel.isEditing) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: viewModel.saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(
    BuildContext context,
    String label,
    TextEditingController controller,
    bool isEditing,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: isEditing,
          decoration: InputDecoration(
            filled: !isEditing,
            fillColor: !isEditing ? Colors.grey.withOpacity(0.1) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  ProfileViewModel viewModelBuilder(BuildContext context) => ProfileViewModel();
}
