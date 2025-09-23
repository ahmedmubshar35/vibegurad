import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'home_viewmodel.dart';
import '../../../models/timer/timer_session.dart';


class HomeView extends StackedView<HomeViewModel> {
  const HomeView({super.key});

  @override
  void onViewModelReady(HomeViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.initializeIfNeeded();
    // Removed camera permission check - handled once at app startup
  }

  @override
  Widget builder(BuildContext context, HomeViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            // App Logo
            const Icon(
              Icons.security,
              size: 32,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text('VibeGuard'),
            const SizedBox(width: 8),
            // Offline indicator
            if (viewModel.isOfflineMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'OFFLINE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Accessibility indicator
          if (viewModel.hasAccessibilityEnabled)
            IconButton(
              icon: const Icon(Icons.accessibility),
              onPressed: () => viewModel.navigateToAccessibility(context),
              tooltip: 'Accessibility enabled',
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: viewModel.navigateToProfile,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: viewModel.signOut,
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                // Refresh data
                viewModel.notifyListeners();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Message
                    _buildWelcomeSection(context, viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Active Session Card
                    if (viewModel.hasActiveSession)
                      _buildActiveSessionCard(context, viewModel),
                    
                    if (viewModel.hasActiveSession)
                      const SizedBox(height: 24),
                    
                    // Quick Actions
                    _buildQuickActionsSection(context, viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Today's Exposure Summary
                    _buildExposureSummaryCard(context, viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Recent Activity
                    _buildRecentActivitySection(context, viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Safety Tips
                    _buildSafetyTipsCard(context, viewModel),
                    
                    const SizedBox(height: 24),
                    
                    // Tools & Support
                    _buildToolsAndSupportSection(context, viewModel),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _buildBottomNavigation(context, viewModel),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.navigateToHelp(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.help_outline, color: Colors.white),
        tooltip: 'Get Help',
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context, HomeViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.welcomeMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            viewModel.safetyStatusMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context, HomeViewModel viewModel) {
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: viewModel.getExposureColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: viewModel.getExposureColor(),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: viewModel.getExposureColor(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Session',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: viewModel.getExposureColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: viewModel.getExposureColor(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    viewModel.isTimerRunning ? 'RUNNING' : 'PAUSED',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (viewModel.currentTool != null) ...[
              Text(
                'Tool: ${viewModel.currentTool!.name}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              'Duration: ${viewModel.formatDuration(viewModel.currentExposure)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: viewModel.getExposureColor(),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: viewModel.toggleSessionPause,
                    icon: Icon(
                      viewModel.isTimerRunning ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(viewModel.isTimerRunning ? 'Pause' : 'Resume'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: viewModel.getExposureColor(),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: viewModel.stopCurrentSession,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: viewModel.getExposureColor(),
                      side: BorderSide(color: viewModel.getExposureColor()),
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

  Widget _buildQuickActionsSection(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Scan Tool',
                'Use AI recognition',
                Icons.camera_alt,
                Theme.of(context).colorScheme.primary,
                viewModel.startToolRecognition,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Manual Start',
                'Select tool manually',
                Icons.build,
                Colors.orange,
                viewModel.quickStartManualTool,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'History',
                'View past sessions',
                Icons.history,
                Colors.green,
                viewModel.navigateToHistory,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Dashboard',
                'Manager view',
                Icons.dashboard,
                Colors.purple,
                viewModel.navigateToDashboard,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExposureSummaryCard(BuildContext context, HomeViewModel viewModel) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Exposure',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Total Time',
                    viewModel.formatDuration(
                      Duration(minutes: viewModel.todayExposureMinutes),
                    ),
                    Icons.access_time,
                    viewModel.getExposureColor(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    context,
                    'Daily Limit',
                    '${viewModel.todayExposurePercentage.toInt()}%',
                    Icons.trending_up,
                    viewModel.getExposureColor(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: viewModel.todayExposurePercentage / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(viewModel.getExposureColor()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: viewModel.navigateToHistory,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: viewModel.recentSessions.isEmpty
                ? _buildNoActivityMessage(context)
                : Column(
                    children: viewModel.recentSessions
                        .asMap()
                        .entries
                        .map((entry) {
                      final index = entry.key;
                      final session = entry.value;
                      return Column(
                        children: [
                          if (index > 0) const Divider(),
                          _buildActivityItemFromSession(context, session),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoActivityMessage(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.history,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        const SizedBox(height: 8),
        Text(
          'No recent activity',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Start using tools to see your activity here',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActivityItemFromSession(BuildContext context, TimerSession session) {
    // Extract session data - use tool name if available, otherwise use tool ID
    final toolName = session.tool?.name ?? session.toolId;
    final duration = session.endTime != null 
        ? '${session.totalMinutes} min'
        : 'Active';
    
    // Calculate time ago
    final timeAgo = _getTimeAgo(session.startTime);
    
    // Get color and icon based on tool type or duration
    final color = _getToolColor(toolName);
    final icon = _getToolIcon(toolName);

    return _buildActivityItem(
      context,
      toolName,
      timeAgo,
      duration,
      icon,
      color,
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Color _getToolColor(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('drill')) return Colors.orange;
    if (lowerName.contains('grinder')) return Colors.red;
    if (lowerName.contains('hammer')) return Colors.purple;
    if (lowerName.contains('saw')) return Colors.blue;
    if (lowerName.contains('sand')) return Colors.green;
    return Colors.grey;
  }

  IconData _getToolIcon(String toolName) {
    final lowerName = toolName.toLowerCase();
    if (lowerName.contains('drill')) return Icons.build;
    if (lowerName.contains('grinder')) return Icons.build_circle;
    if (lowerName.contains('hammer')) return Icons.construction;
    if (lowerName.contains('saw')) return Icons.carpenter;
    if (lowerName.contains('sand')) return Icons.brush;
    return Icons.handyman;
  }

  Widget _buildActivityItem(
    BuildContext context,
    String toolName,
    String time,
    String duration,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                toolName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          duration,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTipsCard(BuildContext context, HomeViewModel viewModel) {
    final safetyTip = _getSafetyTip(viewModel.todayExposurePercentage, viewModel.recentSessions);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  safetyTip['icon'] as IconData,
                  color: safetyTip['color'] as Color,
                ),
                const SizedBox(width: 8),
                Text(
                  safetyTip['title'] as String,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(safetyTip['message'] as String),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getSafetyTip(double exposurePercentage, List<dynamic> recentSessions) {
    // High exposure warnings
    if (exposurePercentage >= 100) {
      return {
        'icon': Icons.warning,
        'color': Colors.red,
        'title': 'Critical Alert',
        'message': 'You have exceeded your daily exposure limit! Stop using vibrating tools immediately and take extended breaks to prevent HAVS.',
      };
    } else if (exposurePercentage >= 80) {
      return {
        'icon': Icons.warning_amber,
        'color': Colors.orange,
        'title': 'High Exposure Warning',
        'message': 'You are approaching your daily limit. Consider switching to lower-vibration tools or taking longer breaks between sessions.',
      };
    } else if (exposurePercentage >= 50) {
      return {
        'icon': Icons.schedule,
        'color': Colors.amber,
        'title': 'Moderate Exposure',
        'message': 'Take regular 10-minute breaks every hour when using high-vibration tools. Keep your hands warm and dry.',
      };
    }

    // Tips based on recent activity
    if (recentSessions.isNotEmpty) {
      return {
        'icon': Icons.lightbulb_outline,
        'color': Colors.green,
        'title': 'Good Progress',
        'message': 'Great job monitoring your exposure! Remember to use anti-vibration gloves and maintain proper grip techniques.',
      };
    }

    // Default tip for new users
    return {
      'icon': Icons.info_outline,
      'color': Colors.blue,
      'title': 'Welcome to Safety Monitoring',
      'message': 'Start using the tool scanner to track your exposure to vibrating tools. This helps prevent Hand-Arm Vibration Syndrome (HAVS).',
    };
  }

  Widget _buildToolsAndSupportSection(BuildContext context, HomeViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tools & Support',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Help & FAQ',
                'Get help and answers',
                Icons.help_outline,
                Colors.blue,
                () => viewModel.navigateToHelp(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Send Feedback',
                'Report issues or suggestions',
                Icons.feedback_outlined,
                Colors.orange,
                () => viewModel.navigateToFeedback(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Accessibility',
                'Text size, contrast, animations',
                Icons.accessibility,
                Colors.purple,
                () => viewModel.navigateToAccessibility(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Offline Mode',
                'Manage offline settings',
                Icons.cloud_off,
                Colors.grey,
                () => viewModel.navigateToOfflineMode(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Performance',
                'Monitor app performance',
                Icons.speed,
                Colors.green,
                () => viewModel.navigateToPerformance(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Tool Management',
                'View and manage company tools',
                Icons.build_circle,
                Colors.teal,
                () => viewModel.navigateToToolManagement(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Maintenance',
                'Schedule and track maintenance',
                Icons.build,
                Colors.blue,
                () => viewModel.navigateToMaintenance(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                'Reports',
                'View compliance and safety reports',
                Icons.assessment,
                Colors.purple,
                () => viewModel.navigateToReports(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigation(BuildContext context, HomeViewModel viewModel) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0, // Home is selected
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.camera_alt),
          label: 'Scan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.timer),
          label: 'Timer',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            // Already on home
            break;
          case 1:
            viewModel.startToolRecognition();
            break;
          case 2:
            viewModel.navigateToTimer();
            break;
          case 3:
            viewModel.navigateToHistory();
            break;
          case 4:
            viewModel.navigateToMore();
            break;
        }
      },
    );
  }


  @override
  HomeViewModel viewModelBuilder(BuildContext context) => HomeViewModel();
}