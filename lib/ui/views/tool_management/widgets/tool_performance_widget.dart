import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolPerformanceWidget extends StatelessWidget {
  final List<ToolPerformanceMetric> performanceMetrics;
  final List<ToolPerformanceMetric> decliningTools;
  final VoidCallback onRecordMetric;
  final Function(ToolPerformanceMetric) onViewTrends;
  final Function(ToolPerformanceMetric) onGenerateAlert;

  const ToolPerformanceWidget({
    super.key,
    required this.performanceMetrics,
    required this.decliningTools,
    required this.onRecordMetric,
    required this.onViewTrends,
    required this.onGenerateAlert,
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
                'Performance Tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onRecordMetric,
                icon: const Icon(Icons.timeline, size: 16),
                label: const Text('Record Metric'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (decliningTools.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Text(
                '${decliningTools.length} tools showing performance decline',
                style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: ListView.builder(
              itemCount: performanceMetrics.length,
              itemBuilder: (context, index) {
                final metric = performanceMetrics[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _isDecline(metric) ? Colors.red : Colors.green,
                      child: Icon(
                        _isDecline(metric) ? Icons.trending_down : Icons.trending_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text('${metric.metricType} Metric'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Value: ${metric.value} ${metric.unit}'),
                        Text('Recorded: ${_formatDate(metric.recordedDate)}'),
                        if (metric.recordedByWorkerId != null)
                          Text('By: Worker ${metric.recordedByWorkerId}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'trends':
                            onViewTrends(metric);
                            break;
                          case 'alert':
                            onGenerateAlert(metric);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'trends',
                          child: Text('View Trends'),
                        ),
                        const PopupMenuItem(
                          value: 'alert',
                          child: Text('Generate Alert'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isDecline(ToolPerformanceMetric metric) {
    // Simple heuristic: if metric type suggests lower is better (like time/duration)
    // or if value is significantly below typical ranges
    switch (metric.metricType.toLowerCase()) {
      case 'time':
      case 'duration':
      case 'delay':
        return metric.value > 100; // Arbitrary threshold for demo
      case 'efficiency':
      case 'accuracy':
      case 'speed':
      case 'quality':
        return metric.value < 50; // Below 50% might indicate decline
      default:
        return false;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}