import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../models/admin/dashboard_models.dart';
import '../../../models/health/lifetime_exposure.dart';
import '../../../services/admin/admin_analytics_service.dart';
import '../../../services/admin/worker_monitoring_service.dart';
import '../../../services/admin/safety_violation_service.dart';
import '../../../services/admin/custom_report_service.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<AdminDashboardViewModel>.reactive(
      viewModelBuilder: () => AdminDashboardViewModel(),
      onViewModelReady: (model) => model.initialize(),
      builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('👨‍💼 Admin Dashboard'),
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: model.refresh,
                tooltip: 'Refresh Dashboard',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => _showDashboardSettings(context, model),
                tooltip: 'Dashboard Settings',
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuSelection(context, model, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export_report',
                    child: Row(
                      children: [
                        Icon(Icons.file_download),
                        SizedBox(width: 8),
                        Text('Export Report'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'schedule_report',
                    child: Row(
                      children: [
                        Icon(Icons.schedule),
                        SizedBox(width: 8),
                        Text('Schedule Report'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'alert_settings',
                    child: Row(
                      children: [
                        Icon(Icons.notification_important),
                        SizedBox(width: 8),
                        Text('Alert Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: model.refresh,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dashboard Summary Cards
                        if (model.dashboardSummary != null)
                          _buildDashboardSummaryCard(model.dashboardSummary!),
                        
                        const SizedBox(height: 16),
                        
                        // Real-time Worker Monitoring Map
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.map, color: Colors.green),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Real-time Worker Monitoring',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Chip(
                                      label: Text('${model.activeWorkerCount} Active'),
                                      backgroundColor: Colors.green[100],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 300,
                                  child: _buildWorkerMonitoringMap(model.monitoringData),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // High-Risk Workers & Department Comparison
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // High-Risk Workers
                            Expanded(
                              flex: 1,
                              child: _buildHighRiskWorkersList(context, model.highRiskWorkers),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Department Comparison
                            Expanded(
                              flex: 1,
                              child: _buildDepartmentComparisonChart(context, model.departmentComparisons),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Safety Violations & Budget Impact
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Violation Trends
                            Expanded(
                              flex: 1,
                              child: _buildViolationTrendChart(context, model),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Budget Impact
                            Expanded(
                              flex: 1,
                              child: _buildBudgetImpactCard(context, model),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Worker Leaderboard & Tool Analytics
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Worker Leaderboard
                            Expanded(
                              flex: 1,
                              child: _buildWorkerLeaderboard(context, model),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            // Tool Usage Analytics
                            Expanded(
                              flex: 1,
                              child: _buildToolUsageAnalyticsCard(context, model),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Quick Actions
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quick Actions',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildQuickActionButton(
                                      'Generate Report',
                                      Icons.assessment,
                                      Colors.blue,
                                      () => _generateQuickReport(context, model),
                                    ),
                                    _buildQuickActionButton(
                                      'Export Data',
                                      Icons.file_download,
                                      Colors.green,
                                      () => _exportDashboardData(context, model),
                                    ),
                                    _buildQuickActionButton(
                                      'Send Alerts',
                                      Icons.notifications,
                                      Colors.orange,
                                      () => _sendBatchAlerts(context, model),
                                    ),
                                    _buildQuickActionButton(
                                      'Schedule Task',
                                      Icons.schedule,
                                      Colors.purple,
                                      () => _scheduleTask(context, model),
                                    ),
                                    _buildQuickActionButton(
                                      'System Health',
                                      Icons.health_and_safety,
                                      Colors.teal,
                                      () => _showSystemHealth(context, model),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, AdminDashboardViewModel model, String value) {
    switch (value) {
      case 'export_report':
        _exportDashboardData(context, model);
        break;
      case 'schedule_report':
        _scheduleReport(context, model);
        break;
      case 'alert_settings':
        _showAlertSettings(context, model);
        break;
    }
  }

  void _showDashboardSettings(BuildContext context, AdminDashboardViewModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dashboard Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Real-time Updates'),
              value: model.realTimeUpdatesEnabled,
              onChanged: model.toggleRealTimeUpdates,
            ),
            SwitchListTile(
              title: const Text('Auto-refresh'),
              value: model.autoRefreshEnabled,
              onChanged: model.toggleAutoRefresh,
            ),
            ListTile(
              title: const Text('Refresh Interval'),
              subtitle: Text('${model.refreshIntervalMinutes} minutes'),
              trailing: DropdownButton<int>(
                value: model.refreshIntervalMinutes,
                items: [1, 2, 5, 10, 15, 30].map((min) {
                  return DropdownMenuItem(
                    value: min,
                    child: Text('$min min'),
                  );
                }).toList(),
                onChanged: model.setRefreshInterval,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showWorkerDetails(BuildContext context, dynamic workerId) {
    // Navigate to worker details page
    Navigator.pushNamed(context, '/worker-details', arguments: workerId);
  }

  void _showWorkerRiskDetails(BuildContext context, HighRiskWorkerProfile worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('High-Risk Worker: ${worker.workerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Department: ${worker.department}'),
            Text('Risk Score: ${worker.riskScore.toStringAsFixed(1)}/100'),
            Text('Risk Level: ${worker.riskLevel.name.toUpperCase()}'),
            Text('HAVS Stage: ${worker.havsStage}'),
            if (worker.requiresImmediateAction)
              const Chip(
                label: Text('IMMEDIATE ACTION REQUIRED'),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white),
              ),
            const SizedBox(height: 8),
            const Text('Risk Factors:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...worker.riskFactors.map((factor) => Text('• $factor')),
            const SizedBox(height: 8),
            const Text('Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...worker.recommendations.map((rec) => Text('• $rec')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showWorkerDetails(context, worker.workerId);
            },
            child: const Text('View Full Profile'),
          ),
        ],
      ),
    );
  }

  void _showDepartmentDetails(BuildContext context, DepartmentComparison department) {
    // Navigate to department details page
    Navigator.pushNamed(context, '/department-details', arguments: department.departmentId);
  }

  void _showViolationDetails(BuildContext context, AdminDashboardViewModel model) {
    // Navigate to violations page
    Navigator.pushNamed(context, '/violations');
  }

  void _showBudgetDetails(BuildContext context, AdminDashboardViewModel model) {
    // Navigate to budget analysis page
    Navigator.pushNamed(context, '/budget-analysis');
  }

  void _showToolDetails(BuildContext context, ToolUsageAnalytics tool) {
    // Navigate to tool details page
    Navigator.pushNamed(context, '/tool-details', arguments: tool.toolId);
  }

  void _generateQuickReport(BuildContext context, AdminDashboardViewModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Quick Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard Summary'),
              onTap: () {
                Navigator.of(context).pop();
                model.generateDashboardReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Worker Report'),
              onTap: () {
                Navigator.of(context).pop();
                model.generateWorkerReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('Violations Report'),
              onTap: () {
                Navigator.of(context).pop();
                model.generateViolationsReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Budget Impact Report'),
              onTap: () {
                Navigator.of(context).pop();
                model.generateBudgetReport();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportDashboardData(BuildContext context, AdminDashboardViewModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Dashboard Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV Format'),
              onTap: () {
                Navigator.of(context).pop();
                model.exportData('csv');
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON Format'),
              onTap: () {
                Navigator.of(context).pop();
                model.exportData('json');
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Report'),
              onTap: () {
                Navigator.of(context).pop();
                model.exportData('pdf');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _sendBatchAlerts(BuildContext context, AdminDashboardViewModel model) {
    // Show batch alert dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Batch Alerts'),
        content: const Text('Send alerts to high-risk workers or departments?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              model.sendHighRiskAlerts();
            },
            child: const Text('Send to High-Risk Workers'),
          ),
        ],
      ),
    );
  }

  void _scheduleTask(BuildContext context, AdminDashboardViewModel model) {
    // Navigate to task scheduling page
    Navigator.pushNamed(context, '/schedule-task');
  }

  void _showSystemHealth(BuildContext context, AdminDashboardViewModel model) {
    // Show system health dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('System Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHealthMetric('Database', model.systemHealth['database'] ?? 'Unknown', Colors.green),
            _buildHealthMetric('Analytics', model.systemHealth['analytics'] ?? 'Unknown', Colors.green),
            _buildHealthMetric('Notifications', model.systemHealth['notifications'] ?? 'Unknown', Colors.orange),
            _buildHealthMetric('Scheduled Jobs', model.systemHealth['jobs'] ?? 'Unknown', Colors.green),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String name, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            status == 'Healthy' ? Icons.check_circle : Icons.warning,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$name: $status'),
        ],
      ),
    );
  }

  void _scheduleReport(BuildContext context, AdminDashboardViewModel model) {
    // Navigate to report scheduling page
    Navigator.pushNamed(context, '/schedule-report');
  }

  void _showAlertSettings(BuildContext context, AdminDashboardViewModel model) {
    // Show alert settings dialog
    Navigator.pushNamed(context, '/alert-settings');
  }

  // Dashboard widget builders
  Widget _buildDashboardSummaryCard(AdminDashboardSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total Workers', summary.totalWorkers.toString(), Colors.blue),
                _buildSummaryItem('High Risk', summary.highRiskWorkers.toString(), Colors.red),
                _buildSummaryItem('Violations', summary.todayViolations.toString(), Colors.orange),
                _buildSummaryItem('Budget Saved', '\$${summary.estimatedMonthlySavings.toStringAsFixed(0)}', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildWorkerMonitoringMap(List<WorkerMonitoringData> workers) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text('${workers.length} Active Workers'),
            const Text('Map View Coming Soon', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildHighRiskWorkersList(BuildContext context, List<HighRiskWorkerProfile> workers) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'High-Risk Workers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Chip(
                  label: Text('${workers.length}'),
                  backgroundColor: Colors.red[100],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: workers.length,
                itemBuilder: (context, index) {
                  final worker = workers[index];
                  return ListTile(
                    title: Text(worker.workerName),
                    subtitle: Text(worker.department),
                    trailing: Chip(
                      label: Text('${worker.riskScore.toInt()}'),
                      backgroundColor: _getRiskColor(worker.riskLevel),
                    ),
                    onTap: () => _showWorkerRiskDetails(context, worker),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentComparisonChart(BuildContext context, List<DepartmentComparison> departments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Department Comparison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: departments.length,
                itemBuilder: (context, index) {
                  final dept = departments[index];
                  return ListTile(
                    title: Text(dept.departmentName),
                    subtitle: Text('${dept.workerCount} workers'),
                    trailing: Text('${dept.riskScore.toInt()}%'),
                    onTap: () => _showDepartmentDetails(context, dept),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViolationTrendChart(BuildContext context, AdminDashboardViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Violation Trends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showViolationDetails(context, model),
                  child: const Text('View Details'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.show_chart, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('${model.violationTrends.length} Trends'),
                    const Text('Chart Coming Soon', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetImpactCard(BuildContext context, AdminDashboardViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Budget Impact',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showBudgetDetails(context, model),
                  child: const Text('View Details'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: model.budgetImpact != null
                  ? Column(
                      children: [
                        _buildBudgetMetric(
                          'Claims Saved',
                          '\$${model.budgetImpact!.projectedTotalSavings.toStringAsFixed(0)}',
                          Colors.green,
                        ),
                        _buildBudgetMetric(
                          'ROI',
                          '${model.budgetImpact!.returnOnInvestment.toStringAsFixed(1)}%',
                          Colors.blue,
                        ),
                        _buildBudgetMetric(
                          'Implementation Cost',
                          '\$${model.budgetImpact!.systemImplementationCost.toStringAsFixed(0)}',
                          Colors.orange,
                        ),
                      ],
                    )
                  : const Center(child: Text('No data available')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerLeaderboard(BuildContext context, AdminDashboardViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Worker Leaderboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: model.selectedLeaderboardCategory,
              items: ['safety', 'productivity', 'compliance'].map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  model.changeLeaderboardCategory(value);
                }
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: model.workerRankings.length,
                itemBuilder: (context, index) {
                  final ranking = model.workerRankings[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text('${ranking.rank}'),
                      backgroundColor: _getRankColor(ranking.rank),
                    ),
                    title: Text(ranking.workerName),
                    subtitle: Text(ranking.department),
                    trailing: Text('${ranking.score.toInt()}'),
                    onTap: () => _showWorkerDetails(context, ranking.workerId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolUsageAnalyticsCard(BuildContext context, AdminDashboardViewModel model) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Tool Usage Analytics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: model.toolAnalytics.length,
                itemBuilder: (context, index) {
                  final tool = model.toolAnalytics[index];
                  return ListTile(
                    title: Text(tool.toolName),
                    subtitle: Text('${(tool.totalUsageMinutes / 60).toInt()}h usage'),
                    trailing: Text('${tool.averageVibrationLevel.toStringAsFixed(1)} m/s²'),
                    onTap: () => _showToolDetails(context, tool),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(ExposureRiskLevel riskLevel) {
    switch (riskLevel) {
      case ExposureRiskLevel.veryLow:
        return Colors.green[100]!;
      case ExposureRiskLevel.low:
        return Colors.green[200]!;
      case ExposureRiskLevel.moderate:
        return Colors.yellow[200]!;
      case ExposureRiskLevel.high:
        return Colors.orange[200]!;
      case ExposureRiskLevel.veryHigh:
        return Colors.red[200]!;
      case ExposureRiskLevel.critical:
        return Colors.red[400]!;
    }
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[400]!;
    if (rank == 3) return Colors.brown[300]!;
    return Colors.blue[200]!;
  }
}

/// ViewModel for Admin Dashboard
class AdminDashboardViewModel extends BaseViewModel {
  final AdminAnalyticsService _analytics = AdminAnalyticsService();
  final WorkerMonitoringService _monitoring = WorkerMonitoringService();
  final SafetyViolationService _violations = SafetyViolationService();
  final CustomReportService _reports = CustomReportService();

  // Dashboard data
  AdminDashboardSummary? dashboardSummary;
  List<WorkerMonitoringData> monitoringData = [];
  List<HighRiskWorkerProfile> highRiskWorkers = [];
  List<DepartmentComparison> departmentComparisons = [];
  List<ViolationTrend> violationTrends = [];
  BudgetImpactAnalysis? budgetImpact;
  List<WorkerRanking> workerRankings = [];
  List<ToolUsageAnalytics> toolAnalytics = [];

  // Dashboard settings
  bool realTimeUpdatesEnabled = true;
  bool autoRefreshEnabled = true;
  int refreshIntervalMinutes = 5;
  String selectedLeaderboardCategory = 'safety';

  // System health
  Map<String, String> systemHealth = {
    'database': 'Healthy',
    'analytics': 'Healthy',
    'notifications': 'Warning',
    'jobs': 'Healthy',
  };

  int get activeWorkerCount => monitoringData.where((w) => w.isActive).length;

  /// Initialize dashboard
  Future<void> initialize() async {
    setBusy(true);
    
    try {
      await Future.wait([
        _loadDashboardSummary(),
        _loadMonitoringData(),
        _loadHighRiskWorkers(),
        _loadDepartmentComparisons(),
        _loadViolationTrends(),
        _loadBudgetImpact(),
        _loadWorkerRankings(),
        _loadToolAnalytics(),
      ]);

      if (realTimeUpdatesEnabled) {
        _setupRealTimeUpdates();
      }

      if (autoRefreshEnabled) {
        _setupAutoRefresh();
      }
    } catch (e) {
      print('Error initializing dashboard: $e');
    } finally {
      setBusy(false);
    }
  }

  /// Refresh all dashboard data
  Future<void> refresh() async {
    await initialize();
  }

  /// Load dashboard summary
  Future<void> _loadDashboardSummary() async {
    dashboardSummary = await _analytics.getDashboardSummary();
    notifyListeners();
  }

  /// Load monitoring data
  Future<void> _loadMonitoringData() async {
    // This would be loaded from the monitoring service stream
    monitoringData = []; // Placeholder
    notifyListeners();
  }

  /// Load high-risk workers
  Future<void> _loadHighRiskWorkers() async {
    highRiskWorkers = await _analytics.identifyHighRiskWorkers(limit: 10);
    notifyListeners();
  }

  /// Load department comparisons
  Future<void> _loadDepartmentComparisons() async {
    departmentComparisons = await _analytics.getDepartmentComparisons();
    notifyListeners();
  }

  /// Load violation trends
  Future<void> _loadViolationTrends() async {
    violationTrends = await _violations.getViolationTrends();
    notifyListeners();
  }

  /// Load budget impact
  Future<void> _loadBudgetImpact() async {
    budgetImpact = await _analytics.calculateBudgetImpact();
    notifyListeners();
  }

  /// Load worker rankings
  Future<void> _loadWorkerRankings() async {
    workerRankings = await _analytics.generateWorkerRankings(
      category: selectedLeaderboardCategory,
      limit: 20,
    );
    notifyListeners();
  }

  /// Load tool analytics
  Future<void> _loadToolAnalytics() async {
    toolAnalytics = await _analytics.getToolUsageAnalytics();
    notifyListeners();
  }

  /// Setup real-time updates
  void _setupRealTimeUpdates() {
    _monitoring.monitoringStream.listen((workers) {
      monitoringData = workers;
      notifyListeners();
    });

    _violations.violationStream.listen((violation) {
      // Refresh relevant data when new violations occur
      _loadViolationTrends();
      _loadDashboardSummary();
    });
  }

  /// Setup auto-refresh
  void _setupAutoRefresh() {
    Timer.periodic(Duration(minutes: refreshIntervalMinutes), (_) {
      if (autoRefreshEnabled) {
        refresh();
      }
    });
  }

  /// Toggle real-time updates
  void toggleRealTimeUpdates(bool enabled) {
    realTimeUpdatesEnabled = enabled;
    notifyListeners();
    
    if (enabled) {
      _setupRealTimeUpdates();
    }
  }

  /// Toggle auto-refresh
  void toggleAutoRefresh(bool enabled) {
    autoRefreshEnabled = enabled;
    notifyListeners();
    
    if (enabled) {
      _setupAutoRefresh();
    }
  }

  /// Set refresh interval
  void setRefreshInterval(int? minutes) {
    if (minutes != null) {
      refreshIntervalMinutes = minutes;
      notifyListeners();
      
      if (autoRefreshEnabled) {
        _setupAutoRefresh();
      }
    }
  }

  /// Change leaderboard category
  Future<void> changeLeaderboardCategory(String category) async {
    selectedLeaderboardCategory = category;
    await _loadWorkerRankings();
  }

  /// Generate reports
  Future<void> generateDashboardReport() async {
    // Implementation for dashboard report
    print('Generating dashboard report...');
  }

  Future<void> generateWorkerReport() async {
    // Implementation for worker report
    print('Generating worker report...');
  }

  Future<void> generateViolationsReport() async {
    // Implementation for violations report
    print('Generating violations report...');
  }

  Future<void> generateBudgetReport() async {
    // Implementation for budget report
    print('Generating budget report...');
  }

  /// Export data
  Future<void> exportData(String format) async {
    try {
      final insights = await _reports.generateDashboardInsights();
      print('Exporting dashboard data in $format format...');
      // Implementation would depend on format
    } catch (e) {
      print('Error exporting data: $e');
    }
  }

  /// Send high-risk alerts
  Future<void> sendHighRiskAlerts() async {
    print('Sending alerts to high-risk workers...');
    // Implementation for sending batch alerts
  }
}