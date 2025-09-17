import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
// Chart library removed - using custom widgets
import 'package:intl/intl.dart';

import 'reports_viewmodel.dart';

class ReportsView extends StackedView<ReportsViewModel> {
  const ReportsView({super.key});

  @override
  Widget builder(BuildContext context, ReportsViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: viewModel.exportReport,
            tooltip: 'Export Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: viewModel.refreshReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.refreshReport,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Controls Section
                    _buildControlsSection(context, viewModel),
                    
                    const SizedBox(height: 20),
                    
                    // Report Content
                    _buildReportContent(context, viewModel),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildControlsSection(BuildContext context, ReportsViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Report Type Selector
            Row(
              children: [
                Icon(Icons.analytics, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Report Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: viewModel.selectedReportType,
                  onChanged: (value) => viewModel.changeReportType(value!),
                  items: viewModel.reportTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(viewModel.reportTypeNames[type]!),
                  )).toList(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Date Range Selector
            Row(
              children: [
                Icon(Icons.date_range, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Date Range',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _selectDateRange(context, viewModel),
                  child: Text(
                    viewModel.selectedDateRange != null
                        ? '${DateFormat('MMM dd').format(viewModel.selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(viewModel.selectedDateRange!.end)}'
                        : 'Select Range',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, ReportsViewModel viewModel) {
    switch (viewModel.selectedReportType) {
      case 'overview':
        return _buildOverviewReport(context, viewModel);
      case 'safety':
        return _buildSafetyReport(context, viewModel);
      case 'exposure':
        return _buildExposureReport(context, viewModel);
      case 'workers':
        return _buildWorkersReport(context, viewModel);
      case 'tools':
        return _buildToolsReport(context, viewModel);
      case 'compliance':
        return _buildComplianceReport(context, viewModel);
      case 'osha':
        return _buildOSHAReport(context, viewModel);
      case 'iso5349':
        return _buildISO5349Report(context, viewModel);
      case 'violations':
        return _buildViolationsReport(context, viewModel);
      case 'corrective_actions':
        return _buildCorrectiveActionsReport(context, viewModel);
      case 'training':
        return _buildTrainingReport(context, viewModel);
      case 'audit_trail':
        return _buildAuditTrailReport(context, viewModel);
      default:
        return _buildOverviewReport(context, viewModel);
    }
  }

  Widget _buildOverviewReport(BuildContext context, ReportsViewModel viewModel) {
    final data = viewModel.reportData;
    
    return Column(
      children: [
        // Key Metrics Grid
        _buildMetricsGrid(context, [
          {
            'title': 'Total Sessions',
            'value': '${data['totalSessions'] ?? 0}',
            'icon': Icons.timer,
            'color': Colors.blue,
          },
          {
            'title': 'Total Exposure',
            'value': '${(data['totalExposureHours'] ?? 0.0).toStringAsFixed(1)}h',
            'icon': Icons.access_time,
            'color': Colors.orange,
          },
          {
            'title': 'Active Workers',
            'value': '${data['uniqueWorkers'] ?? 0}',
            'icon': Icons.people,
            'color': Colors.green,
          },
          {
            'title': 'Compliance Rate',
            'value': viewModel.formatPercentage(data['complianceRate'] ?? 0.0),
            'icon': Icons.shield,
            'color': viewModel.getComplianceColor(data['complianceRate'] ?? 0.0),
          },
        ]),
        
        const SizedBox(height: 20),
        
        // Compliance Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compliance Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: _buildSimplePieChart(
                    context,
                    [
                      {'value': data['complianceRate'] ?? 0.0, 'label': 'Compliant', 'color': Colors.green},
                      {'value': 100 - (data['complianceRate'] ?? 0.0), 'label': 'Non-Compliant', 'color': Colors.red},
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Summary Information
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Period Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Report Period: ${data['dateRange'] ?? 'N/A'}'),
                const SizedBox(height: 8),
                Text('Average Session Length: ${viewModel.formatDuration((data['averageSessionLength'] ?? 0.0).round())}'),
                const SizedBox(height: 8),
                Text('Sessions with Issues: ${data['sessionsWithIssues'] ?? 0}'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyReport(BuildContext context, ReportsViewModel viewModel) {
    final data = viewModel.reportData;
    final riskDistribution = data['riskDistribution'] as Map<String, int>? ?? {};
    
    return Column(
      children: [
        // Safety Metrics
        _buildMetricsGrid(context, [
          {
            'title': 'High Risk Sessions',
            'value': '${data['highRiskSessions'] ?? 0}',
            'icon': Icons.warning,
            'color': Colors.red,
          },
          {
            'title': 'Emergency Stops',
            'value': '${data['emergencyStops'] ?? 0}',
            'icon': Icons.stop,
            'color': Colors.red,
          },
          {
            'title': 'Over Limit',
            'value': '${data['overLimitSessions'] ?? 0}',
            'icon': Icons.timer_off,
            'color': Colors.orange,
          },
          {
            'title': 'Safety Trend',
            'value': '${data['safetyTrend'] ?? 'Stable'}',
            'icon': Icons.trending_up,
            'color': data['safetyTrend'] == 'Improving' ? Colors.green : 
                    data['safetyTrend'] == 'Declining' ? Colors.red : Colors.blue,
          },
        ]),
        
        const SizedBox(height: 20),
        
        // Risk Distribution Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Level Distribution',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: _buildSimpleBarChart(
                    context,
                    riskDistribution,
                    [Colors.green, Colors.blue, Colors.orange, Colors.red],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Common Issues
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Common Issues',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...(data['mostCommonIssues'] as List<String>? ?? [])
                    .take(5)
                    .map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(issue)),
                        ],
                      ),
                    ))
                    .toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExposureReport(BuildContext context, ReportsViewModel viewModel) {
    final data = viewModel.reportData;
    final dailyExposures = data['dailyExposures'] as List<Map<String, dynamic>>? ?? [];
    final exposureByTool = data['exposureByTool'] as Map<String, int>? ?? {};
    
    return Column(
      children: [
        // Exposure Metrics
        _buildMetricsGrid(context, [
          {
            'title': 'Total Exposure',
            'value': viewModel.formatDuration(data['totalExposureMinutes'] ?? 0),
            'icon': Icons.timer,
            'color': Colors.blue,
          },
          {
            'title': 'Daily Average',
            'value': viewModel.formatDuration((data['averageDailyExposure'] ?? 0.0).round()),
            'icon': Icons.today,
            'color': Colors.green,
          },
          {
            'title': 'Weekly Average',
            'value': viewModel.formatDuration((data['weeklyAverages'] ?? 0.0).round()),
            'icon': Icons.view_week,
            'color': Colors.orange,
          },
          {
            'title': 'Over Limit Days',
            'value': '${dailyExposures.where((d) => d['isOverLimit'] == true).length}',
            'icon': Icons.warning,
            'color': Colors.red,
          },
        ]),
        
        const SizedBox(height: 20),
        
        // Daily Exposure Trend
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Exposure Trend',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: _buildSimpleLineChart(context, [], []), /* LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: dailyExposures.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              (entry.value['exposure'] as int).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        ),
                        // Add limit line at 360 minutes
                        LineChartBarData(
                          spots: List.generate(
                            dailyExposures.length,
                            (index) => FlSpot(index.toDouble(), 360),
                          ),
                          isCurved: false,
                          color: Colors.red,
                          barWidth: 2,
                          dotData: FlDotData(show: false),
                          dashArray: [5, 5],
                        ),
                      ],
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < dailyExposures.length) {
                                final date = dailyExposures[value.toInt()]['date'] as DateTime;
                                return Text(DateFormat('MM/dd').format(date));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text('${value.toInt()}m');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                    ),
                  ), */
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Exposure by Tool
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exposure by Tool',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...exposureByTool.entries
                    .take(5)
                    .map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            viewModel.formatDuration(entry.value),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ))
                    .toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkersReport(BuildContext context, ReportsViewModel viewModel) {
    if (!viewModel.isManager) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Manager Access Required',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Worker reports are only available to managers and administrators.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    final data = viewModel.reportData;
    final workerStats = data['workerStats'] as Map<String, Map<String, dynamic>>? ?? {};
    final topPerformers = data['topPerformers'] as List<Map<String, dynamic>>? ?? [];
    final needingAttention = data['workersNeedingAttention'] as List<Map<String, dynamic>>? ?? [];
    
    return Column(
      children: [
        // Worker Summary
        _buildMetricsGrid(context, [
          {
            'title': 'Total Workers',
            'value': '${workerStats.length}',
            'icon': Icons.people,
            'color': Colors.blue,
          },
          {
            'title': 'Top Performers',
            'value': '${topPerformers.length}',
            'icon': Icons.star,
            'color': Colors.green,
          },
          {
            'title': 'Need Attention',
            'value': '${needingAttention.length}',
            'icon': Icons.warning,
            'color': Colors.red,
          },
          {
            'title': 'Average Sessions',
            'value': workerStats.isNotEmpty ? 
                '${(workerStats.values.fold(0, (sum, w) => sum + (w['totalSessions'] as int)) / workerStats.length).round()}' : '0',
            'icon': Icons.timer,
            'color': Colors.orange,
          },
        ]),
        
        const SizedBox(height: 20),
        
        // Top Performers
        if (topPerformers.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Top Performers',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...topPerformers.take(5).map((worker) => 
                    _buildWorkerRow(context, viewModel, worker, Colors.green)
                  ).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        
        // Workers Needing Attention
        if (needingAttention.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'Needs Attention',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...needingAttention.take(5).map((worker) => 
                    _buildWorkerRow(context, viewModel, worker, Colors.red)
                  ).toList(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkerRow(BuildContext context, ReportsViewModel viewModel, Map<String, dynamic> worker, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  worker['name'] ?? 'Unknown Worker',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: viewModel.getRiskColor(worker['riskLevel'] ?? 'Low'),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  worker['riskLevel'] ?? 'Low',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sessions: ${worker['totalSessions'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Compliance: ${viewModel.formatPercentage(worker['complianceRate'] ?? 0.0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolsReport(BuildContext context, ReportsViewModel viewModel) {
    final data = viewModel.reportData;
    final toolUsage = data['toolUsage'] as Map<String, Map<String, dynamic>>? ?? {};
    final mostUsed = data['mostUsedTools'] as List<Map<String, dynamic>>? ?? [];
    final highestRisk = data['highestRiskTools'] as List<Map<String, dynamic>>? ?? [];
    
    return Column(
      children: [
        // Tool Summary
        _buildMetricsGrid(context, [
          {
            'title': 'Total Tools',
            'value': '${toolUsage.length}',
            'icon': Icons.build,
            'color': Colors.blue,
          },
          {
            'title': 'Most Used',
            'value': mostUsed.isNotEmpty ? mostUsed.first['name'] : 'N/A',
            'icon': Icons.trending_up,
            'color': Colors.green,
          },
          {
            'title': 'High Risk Tools',
            'value': '${highestRisk.length}',
            'icon': Icons.warning,
            'color': Colors.red,
          },
          {
            'title': 'Avg Issue Rate',
            'value': toolUsage.isNotEmpty ? 
                '${(toolUsage.values.fold(0.0, (sum, t) => sum + (t['issueRate'] as double)) / toolUsage.length).toStringAsFixed(1)}%' : '0%',
            'icon': Icons.analytics,
            'color': Colors.orange,
          },
        ]),
        
        const SizedBox(height: 20),
        
        // Most Used Tools
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Used Tools',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...mostUsed.take(5).map((tool) => 
                  _buildToolRow(context, viewModel, tool, Colors.blue)
                ).toList(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // High Risk Tools
        if (highestRisk.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        'High Risk Tools',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...highestRisk.take(5).map((tool) => 
                    _buildToolRow(context, viewModel, tool, Colors.red)
                  ).toList(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildToolRow(BuildContext context, ReportsViewModel viewModel, Map<String, dynamic> tool, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tool['name'] ?? 'Unknown Tool',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sessions: ${tool['totalSessions'] ?? 0}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Usage: ${viewModel.formatDuration(tool['totalExposure'] ?? 0)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Avg Session: ${viewModel.formatDuration((tool['averageSession'] ?? 0.0).round())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Issue Rate: ${viewModel.formatPercentage(tool['issueRate'] ?? 0.0)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: (tool['issueRate'] ?? 0.0) > 20 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceReport(BuildContext context, ReportsViewModel viewModel) {
    final data = viewModel.reportData;
    final hseRequirements = data['hseRequirements'] as Map<String, Map<String, double>>? ?? {};
    final recommendations = data['recommendedActions'] as List<String>? ?? [];
    
    return Column(
      children: [
        // Compliance Overview
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Overall Compliance',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  width: 120,
                  child: CircularProgressIndicator(
                    value: (data['overallComplianceRate'] ?? 0.0) / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      viewModel.getComplianceColor(data['overallComplianceRate'] ?? 0.0),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.formatPercentage(data['overallComplianceRate'] ?? 0.0),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: viewModel.getComplianceColor(data['overallComplianceRate'] ?? 0.0),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // HSE Requirements
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HSE Requirements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...hseRequirements.entries.map((requirement) {
                  final rate = requirement.value['rate'] ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                requirement.key,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              viewModel.formatPercentage(rate),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: viewModel.getComplianceColor(rate),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: rate / 100,
                          backgroundColor: Colors.grey.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            viewModel.getComplianceColor(rate),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Recommendations
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...recommendations.map((recommendation) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(BuildContext context, List<Map<String, dynamic>> metrics) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  metric['icon'] as IconData,
                  size: 32,
                  color: metric['color'] as Color,
                ),
                const SizedBox(height: 8),
                Text(
                  metric['value'] as String,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: metric['color'] as Color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  metric['title'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDateRange(BuildContext context, ReportsViewModel viewModel) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: viewModel.selectedDateRange,
    );
    
    if (picked != null) {
      await viewModel.selectDateRange(picked);
    }
  }

  // Custom chart builders to replace fl_chart
  Widget _buildSimplePieChart(BuildContext context, List<Map<String, dynamic>> data) {
    double total = 0;
    for (var item in data) {
      total += (item['value'] as num).toDouble();
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Simple pie representation using containers
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: CustomPaint(
                  painter: SimplePiePainter(data, total),
                ),
              ),
              // Center text
              Text(
                '${data[0]['value'].toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: data.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: item['color'],
                    ),
                    const SizedBox(width: 4),
                    Text(item['label']),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart(BuildContext context, Map<String, int> data, List<Color> colors) {
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    final entries = data.entries.toList();
    
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final height = maxValue > 0 ? (item.value / maxValue) * 150 : 0.0;
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.value.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 40,
                    height: height,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.key,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleLineChart(BuildContext context, List<Map<String, dynamic>> actualData, List<Map<String, dynamic>> targetData) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  'Chart visualization',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 2, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              const Text('Actual'),
              const SizedBox(width: 16),
              Container(width: 20, height: 2, color: Colors.grey),
              const SizedBox(width: 4),
              const Text('Target'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  ReportsViewModel viewModelBuilder(BuildContext context) => ReportsViewModel();
}

// Simple pie chart painter
class SimplePiePainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double total;

  SimplePiePainter(this.data, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -3.14159 / 2; // Start from top

    for (var item in data) {
      final sweepAngle = (item['value'] / total) * 2 * 3.14159;
      final paint = Paint()
        ..color = item['color']
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// New compliance report building methods
Widget _buildOSHAReport(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final oshaRequirements = data['oshaRequirements'] as Map<String, dynamic>;
  final oshaStandards = data['oshaStandards'] as List<String>;
  final recommendations = data['recommendations'] as List<String>;

  return Column(
    children: [
      // OSHA Compliance Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'OSHA Compliance Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: (data['oshaComplianceRate'] ?? 0.0) / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    viewModel.getComplianceColor(data['oshaComplianceRate'] ?? 0.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                viewModel.formatPercentage(data['oshaComplianceRate'] ?? 0.0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: viewModel.getComplianceColor(data['oshaComplianceRate'] ?? 0.0),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Violations: ${data['totalViolations']}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // OSHA Requirements
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OSHA Requirements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...oshaRequirements.entries.map((requirement) {
                final rate = requirement.value['rate'] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              requirement.key,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            viewModel.formatPercentage(rate),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: viewModel.getComplianceColor(rate),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: rate / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          viewModel.getComplianceColor(rate),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // OSHA Standards
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OSHA Standards',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...oshaStandards.map((standard) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        standard,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Recommendations
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OSHA Recommendations',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...recommendations.map((recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildISO5349Report(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final isoRequirements = data['isoRequirements'] as Map<String, dynamic>;
  final isoStandards = data['isoStandards'] as List<String>;
  final recommendations = data['recommendations'] as List<String>;
  final measurementData = data['measurementData'] as Map<String, dynamic>;

  return Column(
    children: [
      // ISO 5349 Compliance Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'ISO 5349 Compliance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: (data['isoComplianceRate'] ?? 0.0) / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    viewModel.getComplianceColor(data['isoComplianceRate'] ?? 0.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                viewModel.formatPercentage(data['isoComplianceRate'] ?? 0.0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: viewModel.getComplianceColor(data['isoComplianceRate'] ?? 0.0),
                ),
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // ISO Requirements
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ISO 5349 Requirements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...isoRequirements.entries.map((requirement) {
                final rate = requirement.value['rate'] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              requirement.key,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            viewModel.formatPercentage(rate),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: viewModel.getComplianceColor(rate),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: rate / 100,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          viewModel.getComplianceColor(rate),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // ISO Standards
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ISO Standards',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...isoStandards.map((standard) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        standard,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Measurement Data
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Measurement Data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...(measurementData['measurements'] as List).map((measurement) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        measurement['tool'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'A(8): ${measurement['a8Value']}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: measurement['compliant'] ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        measurement['compliant'] ? 'Compliant' : 'Non-Compliant',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildViolationsReport(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final violationTypes = data['violationTypes'] as Map<String, dynamic>;
  final topViolators = data['topViolators'] as List<dynamic>;
  final recommendations = data['recommendations'] as List<String>;

  return Column(
    children: [
      // Violations Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Violation Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Total Violations',
                      '${data['totalViolations']}',
                      Icons.warning,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Critical',
                      '${data['criticalViolations']}',
                      Icons.error,
                      Colors.red[800]!,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Warnings',
                      '${data['warningViolations']}',
                      Icons.warning_amber,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Trend',
                      data['violationTrends']['trend'],
                      Icons.trending_down,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Violation Types
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Violation Types',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...violationTypes.entries.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        type.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${type.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Top Violators
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Violators',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...topViolators.map((violator) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      violator['worker'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${violator['violations']} violations',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildCorrectiveActionsReport(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final actionTypes = data['actionTypes'] as Map<String, dynamic>;
  final recommendations = data['recommendations'] as List<String>;

  return Column(
    children: [
      // Corrective Actions Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Corrective Actions Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Total Actions',
                      '${data['totalActions']}',
                      Icons.assignment,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Completed',
                      '${data['completedActions']}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Pending',
                      '${data['pendingActions']}',
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Overdue',
                      '${data['overdueActions']}',
                      Icons.warning,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Action Types
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Action Types',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...actionTypes.entries.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        type.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${type.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildTrainingReport(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final trainingTypes = data['trainingTypes'] as Map<String, dynamic>;
  final certifications = data['certificationStatus'] as Map<String, dynamic>;
  final recommendations = data['recommendations'] as List<String>;

  return Column(
    children: [
      // Training Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Training Compliance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: (data['trainingComplianceRate'] ?? 0.0) / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    viewModel.getComplianceColor(data['trainingComplianceRate'] ?? 0.0),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                viewModel.formatPercentage(data['trainingComplianceRate'] ?? 0.0),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: viewModel.getComplianceColor(data['trainingComplianceRate'] ?? 0.0),
                ),
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Training Types
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Training Types',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...trainingTypes.entries.map((type) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        type.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${type.value} workers',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Certification Status
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Certification Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Current',
                      '${certifications['current']}',
                      Icons.verified,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Expiring',
                      '${certifications['expiring']}',
                      Icons.schedule,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildMetricCard(
                context,
                'Expired',
                '${certifications['expired']}',
                Icons.error,
                Colors.red,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildAuditTrailReport(BuildContext context, ReportsViewModel viewModel) {
  final data = viewModel.reportData;
  final auditCategories = data['auditCategories'] as Map<String, dynamic>;
  final dataIntegrity = data['dataIntegrity'] as Map<String, dynamic>;
  final legalHold = data['legalHoldStatus'] as Map<String, dynamic>;
  final recommendations = data['recommendations'] as List<String>;

  return Column(
    children: [
      // Audit Trail Overview
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Audit Trail Summary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildMetricCard(
                context,
                'Total Audit Events',
                '${data['totalAuditEvents']}',
                Icons.analytics,
                Colors.blue,
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Audit Categories
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Audit Categories',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...auditCategories.entries.map((category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${category.value}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Data Integrity
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data Integrity',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Checksum Valid',
                      '${dataIntegrity['checksumValid']}%',
                      Icons.verified,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      context,
                      'Backup Success',
                      '${dataIntegrity['backupSuccess']}%',
                      Icons.backup,
                      Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Legal Hold Status
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Legal Hold Status',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    legalHold['active'] ? Icons.lock : Icons.lock_open,
                    color: legalHold['active'] ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      legalHold['active'] ? 'Legal Hold Active' : 'No Legal Hold',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: legalHold['active'] ? Colors.red : Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              if (legalHold['active']) ...[
                const SizedBox(height: 8),
                Text(
                  'Reason: ${legalHold['reason']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Data Retention: ${legalHold['dataRetention']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
