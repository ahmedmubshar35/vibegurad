import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:intl/intl.dart';

import 'tool_details_viewmodel.dart';

class ToolDetailsView extends StackedView<ToolDetailsViewModel> {
  final String toolId;
  
  const ToolDetailsView({super.key, required this.toolId});

  @override
  Widget builder(BuildContext context, ToolDetailsViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(viewModel.tool?.displayName ?? 'Tool Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (viewModel.canEdit) ...[
            if (viewModel.isEditing) ...[
              TextButton(
                onPressed: () => viewModel.toggleEditing(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: viewModel.saveChanges,
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: viewModel.toggleEditing,
                tooltip: 'Edit Tool',
              ),
            ],
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  viewModel.refreshData();
                  break;
                case 'toggle_availability':
                  if (viewModel.isManager) viewModel.toggleAvailability();
                  break;
                case 'schedule_maintenance':
                  if (viewModel.isManager) viewModel.scheduleMaintenance();
                  break;
                case 'complete_maintenance':
                  if (viewModel.isManager) viewModel.completeMaintenance();
                  break;
                case 'delete':
                  if (viewModel.canDelete) _showDeleteConfirmation(context, viewModel);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              if (viewModel.isManager) ...[
                PopupMenuItem(
                  value: 'toggle_availability',
                  child: Row(
                    children: [
                      Icon(viewModel.tool?.isToolActive == true ? Icons.visibility_off : Icons.visibility),
                      const SizedBox(width: 8),
                      Text(viewModel.tool?.isToolActive == true ? 'Disable' : 'Enable'),
                    ],
                  ),
                ),
                if (viewModel.tool?.needsMaintenance != true)
                  const PopupMenuItem(
                    value: 'schedule_maintenance',
                    child: Row(
                      children: [
                        Icon(Icons.build_circle),
                        SizedBox(width: 8),
                        Text('Schedule Maintenance'),
                      ],
                    ),
                  ),
                if (viewModel.tool?.needsMaintenance == true)
                  const PopupMenuItem(
                    value: 'complete_maintenance',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle),
                        SizedBox(width: 8),
                        Text('Complete Maintenance'),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text('Delete Tool', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.refreshData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tool Header
                    _buildToolHeader(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Tool Information
                    _buildToolInformation(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Usage Statistics
                    _buildUsageStatistics(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Usage Chart
                    _buildUsageChart(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Recent Sessions
                    _buildRecentSessions(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildActionButtons(context, viewModel),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildToolHeader(BuildContext context, ToolDetailsViewModel viewModel) {
    final tool = viewModel.tool;
    if (tool == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Tool Icon and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.build,
                    size: 32,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tool.brand} ${tool.model}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: viewModel.getToolStatusColor(),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    viewModel.getToolStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildQuickStat(
                    context,
                    'Category',
                    tool.category,
                    Icons.category,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    context,
                    'Vibration Risk',
                    viewModel.getVibrationRiskLevel(),
                    Icons.vibration,
                    viewModel.getVibrationRiskColor(),
                  ),
                ),
                Expanded(
                  child: _buildQuickStat(
                    context,
                    'Last Used',
                    viewModel.formatLastUsed(),
                    Icons.schedule,
                    Colors.orange,
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
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildToolInformation(BuildContext context, ToolDetailsViewModel viewModel) {
    final tool = viewModel.tool;
    if (tool == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tool Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (viewModel.isEditing) ...[
              // Editable fields
              _buildEditableField(
                context,
                'Display Name',
                viewModel.displayNameController,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      context,
                      'Brand',
                      viewModel.brandController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableField(
                      context,
                      'Model',
                      viewModel.modelController,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      context,
                      'Category',
                      viewModel.categoryController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableField(
                      context,
                      'Vibration (m/s²)',
                      viewModel.vibrationController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              _buildEditableField(
                context,
                'Daily Exposure Limit (minutes)',
                viewModel.exposureLimitController,
                keyboardType: TextInputType.number,
              ),
              
              const SizedBox(height: 16),
              
              _buildEditableField(
                context,
                'Description',
                viewModel.descriptionController,
                maxLines: 3,
              ),
            ] else ...[
              // Read-only fields
              _buildInfoRow('Display Name', tool.name),
              _buildInfoRow('Brand', tool.brand),
              _buildInfoRow('Model', tool.model),
              _buildInfoRow('Category', tool.category),
              _buildInfoRow('Vibration Level', '${tool.vibrationLevel.toStringAsFixed(1)} m/s²'),
              _buildInfoRow('Daily Exposure Limit', '${tool.dailyExposureLimit} minutes'),
              _buildInfoRow('Serial Number', tool.serialNumber ?? 'Not specified'),
              if (tool.specifications?.isNotEmpty == true)
                _buildInfoRow('Specifications', tool.specifications.toString()),
              if (tool.createdAt != null)
                _buildInfoRow('Added On', DateFormat('MMM dd, yyyy').format(tool.createdAt!)),
              if (tool.lastMaintenanceDate != null)
                _buildInfoRow('Last Maintenance', DateFormat('MMM dd, yyyy').format(tool.lastMaintenanceDate!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStatistics(BuildContext context, ToolDetailsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildStatCard(
                  context,
                  'Total Sessions',
                  '${viewModel.totalSessions}',
                  Icons.timer,
                  Colors.blue,
                ),
                _buildStatCard(
                  context,
                  'Total Usage',
                  viewModel.formatDuration(viewModel.totalUsageMinutes),
                  Icons.access_time,
                  Colors.green,
                ),
                _buildStatCard(
                  context,
                  'Avg. Session',
                  viewModel.formatDuration(viewModel.averageSessionLength.round()),
                  Icons.trending_up,
                  Colors.orange,
                ),
                _buildStatCard(
                  context,
                  'Unique Users',
                  '${viewModel.uniqueUsers}',
                  Icons.people,
                  Colors.purple,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Additional Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Usage This Week',
                    '${viewModel.usageThisWeek.toStringAsFixed(1)}h',
                    Icons.view_week,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Usage This Month',
                    '${viewModel.usageThisMonth.toStringAsFixed(1)}h',
                    Icons.calendar_month,
                    Colors.indigo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageChart(BuildContext context, ToolDetailsViewModel viewModel) {
    if (viewModel.recentSessions.isEmpty) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Trend (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 20),
            
            SizedBox(
              height: 200,
              child: _buildSimpleChart(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleChart(BuildContext context, ToolDetailsViewModel viewModel) {
    // Simple bar chart using containers
    final chartData = _getChartData(viewModel.recentSessions);
    if (chartData.isEmpty) {
      return Center(
        child: Text(
          'No usage data available',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    
    final maxValue = chartData.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: chartData.entries.map((entry) {
              final height = maxValue > 0 ? (entry.value / maxValue) * 150 : 0.0;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        height: height,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MM/dd').format(DateTime.now().subtract(Duration(days: 6 - entry.key))),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Map<int, int> _getChartData(List<dynamic> sessions) {
    // Simplified chart data - group by day
    final dailyUsage = <int, int>{};
    final now = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      dailyUsage[i] = 0;
    }
    
    for (final session in sessions) {
      final daysDiff = now.difference(session.startTime).inDays;
      if (daysDiff >= 0 && daysDiff < 7) {
        final index = 6 - daysDiff;
        dailyUsage[index] = (dailyUsage[index] ?? 0) + (session.totalMinutes as int);
      }
    }
    
    return dailyUsage;
  }

  Widget _buildRecentSessions(BuildContext context, ToolDetailsViewModel viewModel) {
    if (viewModel.recentSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent sessions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'This tool has not been used recently.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Sessions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: viewModel.viewSessionHistory,
                  child: const Text('View All'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            ...viewModel.recentSessions.take(5).map(
              (session) => _buildSessionRow(context, viewModel, session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionRow(BuildContext context, ToolDetailsViewModel viewModel, dynamic session) {
    return InkWell(
      onTap: () => viewModel.navigateToSessionDetails(session),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.userName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy • HH:mm').format(session.startTime),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  viewModel.formatDuration(session.totalMinutes),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (session.hasWarnings || session.hasAlerts)
                  const Icon(
                    Icons.warning,
                    size: 16,
                    color: Colors.orange,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ToolDetailsViewModel viewModel) {
    return Column(
      children: [
        // Primary Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: viewModel.canStartSession ? viewModel.startTimerSession : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(viewModel.canStartSession ? 'Start Timer Session' : 'Tool Unavailable'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: viewModel.canStartSession ? null : Colors.grey,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Secondary Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: viewModel.viewSessionHistory,
                icon: const Icon(Icons.history),
                label: const Text('History'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: viewModel.refreshData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    ToolDetailsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tool'),
        content: Text(
          'Are you sure you want to delete "${viewModel.tool?.displayName}"? This action cannot be undone and will also delete all associated session data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await viewModel.deleteTool();
    }
  }

  @override
  void onViewModelReady(ToolDetailsViewModel viewModel) {
    viewModel.initialize(toolId);
  }

  @override
  ToolDetailsViewModel viewModelBuilder(BuildContext context) => ToolDetailsViewModel();
}
