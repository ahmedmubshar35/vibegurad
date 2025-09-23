import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'data_usage_viewmodel.dart';

class DataUsageView extends StatelessWidget {
  const DataUsageView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<DataUsageViewModel>.reactive(
      viewModelBuilder: () => DataUsageViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Data Usage'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: viewModel.refreshData,
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
                      // Data Usage Overview
                      _buildDataUsageOverview(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Current Settings
                      _buildDataSettings(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Data Usage Statistics
                      _buildDataStatistics(context, viewModel),
                      const SizedBox(height: 24),
                      
                      // Data Saving Recommendations
                      _buildDataRecommendations(context, viewModel),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDataUsageOverview(BuildContext context, DataUsageViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Usage Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildUsageCard(
                    context,
                    'Today',
                    '${viewModel.dataUsageToday.toStringAsFixed(1)} MB',
                    Icons.today,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUsageCard(
                    context,
                    'This Month',
                    '${viewModel.dataUsageThisMonth.toStringAsFixed(1)} MB',
                    Icons.calendar_month,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  viewModel.connectionType == 'WiFi' ? Icons.wifi : Icons.signal_cellular_4_bar,
                  color: viewModel.connectionType == 'WiFi' ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text('Connected via ${viewModel.connectionType}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSettings(BuildContext context, DataUsageViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Saving Mode'),
              subtitle: const Text('Reduce data usage by limiting background sync'),
              value: viewModel.isDataSavingMode,
              onChanged: viewModel.toggleDataSavingMode,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('WiFi Only Mode'),
              subtitle: const Text('Only sync data when connected to WiFi'),
              value: viewModel.isWifiOnlyMode,
              onChanged: viewModel.toggleWifiOnlyMode,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data Limit Warning'),
              subtitle: Text('Current limit: ${viewModel.dataLimitMB} MB/month'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showDataLimitDialog(context, viewModel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataStatistics(BuildContext context, DataUsageViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Statistics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Average Daily Usage', '${viewModel.averageDailyUsage.toStringAsFixed(1)} MB'),
            _buildStatRow('Peak Usage Day', viewModel.peakUsageDay),
            _buildStatRow('Data Saved This Month', '${viewModel.dataSavedThisMonth.toStringAsFixed(1)} MB'),
            _buildStatRow('WiFi vs Mobile', '${viewModel.wifiUsagePercentage.toStringAsFixed(0)}% WiFi'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRecommendations(BuildContext context, DataUsageViewModel viewModel) {
    final recommendations = viewModel.getDataRecommendations();
    
    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...recommendations.map((rec) => _buildRecommendationTile(context, rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationTile(BuildContext context, Map<String, dynamic> recommendation) {
    Color getColorForType(String type) {
      switch (type) {
        case 'critical':
          return Colors.red;
        case 'warning':
          return Colors.orange;
        case 'suggestion':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final color = getColorForType(recommendation['type']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(recommendation['icon'], color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recommendation['title'],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation['description'],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (recommendation['action'] != null)
            TextButton(
              onPressed: () {
                // Handle recommendation action
              },
              child: Text(recommendation['action']),
            ),
        ],
      ),
    );
  }

  void _showDataLimitDialog(BuildContext context, DataUsageViewModel viewModel) {
    final controller = TextEditingController(text: viewModel.dataLimitMB.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Data Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set your monthly data usage limit (MB):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Data Limit (MB)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                viewModel.setDataLimit(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}


