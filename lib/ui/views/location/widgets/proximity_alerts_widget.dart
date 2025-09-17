import 'package:flutter/material.dart';
import '../../../../models/location/location_models.dart';

class ProximityAlertsWidget extends StatelessWidget {
  final List<ToolProximityAlert> alerts;
  final Function(ToolProximityAlert) onAlertTap;
  final Function(String) onAcknowledge;

  const ProximityAlertsWidget({
    super.key,
    required this.alerts,
    required this.onAlertTap,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Proximity Alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (alerts.where((a) => !a.acknowledged).isNotEmpty)
                  Chip(
                    label: Text('${alerts.where((a) => !a.acknowledged).length}'),
                    backgroundColor: Colors.red[100],
                    labelStyle: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 48,
                            color: Colors.green[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No proximity alerts',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: alerts.length,
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _buildAlertTile(alert);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTile(ToolProximityAlert alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: alert.acknowledged ? null : _getSeverityColor(alert.severity).withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSeverityColor(alert.severity),
          child: Icon(
            _getAlertIcon(alert.alertType),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          _formatAlertTitle(alert.alertType),
          style: TextStyle(
            fontWeight: alert.acknowledged ? FontWeight.normal : FontWeight.bold,
            decoration: alert.acknowledged ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distance: ${alert.distance.toStringAsFixed(1)}m',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              _formatTime(alert.triggeredAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (alert.toolId.isNotEmpty || alert.workerId.isNotEmpty)
              Text(
                '${alert.toolId.isNotEmpty ? 'Tool: ${alert.toolId}' : ''}'
                '${alert.workerId.isNotEmpty ? 'Worker: ${alert.workerId}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getSeverityColor(alert.severity),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                alert.severity.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!alert.acknowledged) ...[
              const SizedBox(height: 4),
              IconButton(
                icon: const Icon(Icons.check, size: 16),
                onPressed: () => onAcknowledge(alert.alertId),
                tooltip: 'Acknowledge',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ],
        ),
        onTap: () => onAlertTap(alert),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'warning':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String alertType) {
    switch (alertType) {
      case 'critical_proximity':
        return Icons.warning;
      case 'proximity_warning':
        return Icons.info;
      case 'area_proximity':
        return Icons.location_on;
      case 'unauthorized_access':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  String _formatAlertTitle(String alertType) {
    return alertType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? '${word[0].toUpperCase()}${word.substring(1)}' 
            : word)
        .join(' ');
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}