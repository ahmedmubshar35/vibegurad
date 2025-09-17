import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolConditionWidget extends StatelessWidget {
  final List<ToolConditionReport> conditionReports;
  final List<ToolConditionReport> requiresAction;
  final VoidCallback onCreateReport;
  final Function(ToolConditionReport) onViewReport;
  final Function(ToolConditionReport) onTakeAction;

  const ToolConditionWidget({
    super.key,
    required this.conditionReports,
    required this.requiresAction,
    required this.onCreateReport,
    required this.onViewReport,
    required this.onTakeAction,
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
                'Tool Condition Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCreateReport,
                icon: const Icon(Icons.assessment, size: 16),
                label: const Text('New Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (requiresAction.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                '${requiresAction.length} reports require immediate action',
                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: conditionReports.length,
              itemBuilder: (context, index) {
                final report = conditionReports[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getConditionColor(report.condition),
                      child: Icon(
                        _getConditionIcon(report.condition),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text('Report #${report.reportId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Condition: ${report.condition.name}'),
                        Text('Inspector: ${report.reportedByWorkerName}'),
                      ],
                    ),
                    trailing: report.requiresImmediate
                        ? IconButton(
                            onPressed: () => onTakeAction(report),
                            icon: const Icon(Icons.warning, color: Colors.red),
                          )
                        : null,
                    onTap: () => onViewReport(report),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getConditionColor(ToolCondition condition) {
    switch (condition) {
      case ToolCondition.excellent:
        return Colors.green;
      case ToolCondition.good:
        return Colors.lightGreen;
      case ToolCondition.fair:
        return Colors.orange;
      case ToolCondition.poor:
        return Colors.red;
      case ToolCondition.damaged:
        return Colors.red[700]!;
      case ToolCondition.needsRepair:
        return Colors.grey;
    }
  }

  IconData _getConditionIcon(ToolCondition condition) {
    switch (condition) {
      case ToolCondition.excellent:
        return Icons.check_circle;
      case ToolCondition.good:
        return Icons.check;
      case ToolCondition.fair:
        return Icons.warning;
      case ToolCondition.poor:
        return Icons.error;
      case ToolCondition.damaged:
        return Icons.error;
      case ToolCondition.needsRepair:
        return Icons.block;
    }
  }
}