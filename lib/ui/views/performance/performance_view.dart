import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/performance_service.dart';
import 'performance_viewmodel.dart';

class PerformanceView extends StatelessWidget {
  const PerformanceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<PerformanceViewModel>.reactive(
      viewModelBuilder: () => PerformanceViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Performance Monitor'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: viewModel.refreshMetrics,
              ),
            ],
          ),
          body: viewModel.isBusy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Performance Overview
                      _buildPerformanceOverview(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Current Metrics
                      _buildCurrentMetrics(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Performance Analysis
                      _buildPerformanceAnalysis(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Performance History Chart
                      _buildPerformanceChart(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Recommendations
                      _buildRecommendations(context, viewModel),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPerformanceOverview(BuildContext context, PerformanceViewModel viewModel) {
    final analysis = viewModel.performanceAnalysis;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(analysis.status),
                  color: _getStatusColor(context, analysis.status),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Performance Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getStatusText(analysis.status),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getStatusColor(context, analysis.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(context, analysis.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${analysis.score}/100',
                    style: TextStyle(
                      color: _getStatusColor(context, analysis.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: analysis.score / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getStatusColor(context, analysis.status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMetrics(BuildContext context, PerformanceViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Metrics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Memory Usage',
                    '${viewModel.memoryUsage.toStringAsFixed(1)} MB',
                    Icons.memory,
                    _getMemoryColor(context, viewModel.memoryUsage),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'CPU Usage',
                    '${viewModel.cpuUsage.toStringAsFixed(1)}%',
                    Icons.speed,
                    _getCpuColor(context, viewModel.cpuUsage),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'Battery Level',
                    '${viewModel.batteryLevel}%',
                    Icons.battery_std,
                    _getBatteryColor(context, viewModel.batteryLevel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    context,
                    'App Size',
                    '${viewModel.appSize.toStringAsFixed(1)} MB',
                    Icons.storage,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
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

  Widget _buildPerformanceAnalysis(BuildContext context, PerformanceViewModel viewModel) {
    final analysis = viewModel.performanceAnalysis;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Analysis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAnalysisItem(
                    context,
                    'Avg Memory',
                    '${analysis.averageMemoryUsage.toStringAsFixed(1)} MB',
                  ),
                ),
                Expanded(
                  child: _buildAnalysisItem(
                    context,
                    'Avg CPU',
                    '${analysis.averageCpuUsage.toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _buildAnalysisItem(
                    context,
                    'Avg Battery',
                    '${analysis.averageBatteryLevel}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildAnalysisItem(
              context,
              'App Launch Time',
              '${viewModel.appLaunchTime.inMilliseconds}ms',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceChart(BuildContext context, PerformanceViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance History',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Performance Chart',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      'Coming Soon',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
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

  Widget _buildRecommendations(BuildContext context, PerformanceViewModel viewModel) {
    final analysis = viewModel.performanceAnalysis;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...analysis.recommendations.map((recommendation) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
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
              )),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return Icons.check_circle;
      case PerformanceStatus.good:
        return Icons.thumb_up;
      case PerformanceStatus.fair:
        return Icons.warning;
      case PerformanceStatus.poor:
        return Icons.error;
      case PerformanceStatus.unknown:
        return Icons.help;
    }
  }

  Color _getStatusColor(BuildContext context, PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return Colors.green;
      case PerformanceStatus.good:
        return Colors.blue;
      case PerformanceStatus.fair:
        return Colors.orange;
      case PerformanceStatus.poor:
        return Colors.red;
      case PerformanceStatus.unknown:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
    }
  }

  String _getStatusText(PerformanceStatus status) {
    switch (status) {
      case PerformanceStatus.excellent:
        return 'Excellent';
      case PerformanceStatus.good:
        return 'Good';
      case PerformanceStatus.fair:
        return 'Fair';
      case PerformanceStatus.poor:
        return 'Poor';
      case PerformanceStatus.unknown:
        return 'Unknown';
    }
  }

  Color _getMemoryColor(BuildContext context, double memoryUsage) {
    if (memoryUsage > 200) return Colors.red;
    if (memoryUsage > 150) return Colors.orange;
    return Colors.green;
  }

  Color _getCpuColor(BuildContext context, double cpuUsage) {
    if (cpuUsage > 80) return Colors.red;
    if (cpuUsage > 60) return Colors.orange;
    return Colors.green;
  }

  Color _getBatteryColor(BuildContext context, int batteryLevel) {
    if (batteryLevel < 20) return Colors.red;
    if (batteryLevel < 50) return Colors.orange;
    return Colors.green;
  }
}

