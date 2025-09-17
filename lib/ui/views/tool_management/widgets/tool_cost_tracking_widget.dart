import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolCostTrackingWidget extends StatelessWidget {
  final List<ToolCostRecord> recentCosts;
  final Map<String, dynamic> budgetAnalysis;
  final List<Map<String, dynamic>> topCostTools;
  final VoidCallback onRecordCost;
  final VoidCallback onViewCostAnalytics;
  final VoidCallback onGenerateReport;

  const ToolCostTrackingWidget({
    super.key,
    required this.recentCosts,
    required this.budgetAnalysis,
    required this.topCostTools,
    required this.onRecordCost,
    required this.onViewCostAnalytics,
    required this.onGenerateReport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Cost Tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: onRecordCost,
                    icon: const Icon(Icons.attach_money, size: 16),
                    label: const Text('Record Cost'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onViewCostAnalytics,
                    icon: const Icon(Icons.analytics),
                    tooltip: 'View Analytics',
                  ),
                  IconButton(
                    onPressed: onGenerateReport,
                    icon: const Icon(Icons.assignment),
                    tooltip: 'Generate Report',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Budget overview
          if (budgetAnalysis.isNotEmpty && budgetAnalysis['actualSpend'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[100]!, Colors.green[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Budget Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800],
                          ),
                        ),
                        Text(
                          '\$${_formatNumber(budgetAnalysis['actualSpend'] ?? 0.0)} / \$${_formatNumber(budgetAnalysis['annualBudget'] ?? 0.0)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  CircularProgressIndicator(
                    value: (budgetAnalysis['budgetUtilization'] ?? 0.0) / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (budgetAnalysis['budgetUtilization'] ?? 0.0) > 90 
                          ? Colors.red 
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(budgetAnalysis['budgetUtilization'] ?? 0.0).toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Recent Costs'),
                      Tab(text: 'Top Cost Tools'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildRecentCostsTab(),
                        _buildTopCostToolsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCostsTab() {
    return ListView.builder(
      itemCount: recentCosts.length,
      itemBuilder: (context, index) {
        final cost = recentCosts[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getCostTypeColor(cost.costType),
              child: Icon(
                _getCostTypeIcon(cost.costType),
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(cost.description),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${cost.costType.name}'),
                Text('Date: ${_formatDate(cost.date)}'),
                if (cost.vendor != null && cost.vendor!.isNotEmpty) Text('Vendor: ${cost.vendor}'),
              ],
            ),
            trailing: Text(
              '\$${cost.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopCostToolsTab() {
    return ListView.builder(
      itemCount: topCostTools.length,
      itemBuilder: (context, index) {
        final tool = topCostTools[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: const Icon(Icons.construction, color: Colors.white, size: 16),
            ),
            title: Text('Tool ID: ${tool['toolId']}'),
            subtitle: Text('Total Cost'),
            trailing: Text(
              '\$${_formatNumber(tool['cost'])}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getCostTypeColor(CostType costType) {
    switch (costType) {
      case CostType.acquisition:
        return Colors.green;
      case CostType.operational:
        return Colors.blue;
      case CostType.maintenance:
        return Colors.orange;
      case CostType.repair:
        return Colors.red;
      case CostType.upgrade:
        return Colors.purple;
      case CostType.depreciation:
        return Colors.grey;
      case CostType.insurance:
        return Colors.indigo;
      case CostType.storage:
        return Colors.brown;
    }
  }

  IconData _getCostTypeIcon(CostType costType) {
    switch (costType) {
      case CostType.acquisition:
        return Icons.shopping_cart;
      case CostType.operational:
        return Icons.business;
      case CostType.maintenance:
        return Icons.build;
      case CostType.repair:
        return Icons.healing;
      case CostType.upgrade:
        return Icons.upgrade;
      case CostType.depreciation:
        return Icons.trending_down;
      case CostType.insurance:
        return Icons.security;
      case CostType.storage:
        return Icons.storage;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatNumber(double number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toStringAsFixed(0);
    }
  }
}