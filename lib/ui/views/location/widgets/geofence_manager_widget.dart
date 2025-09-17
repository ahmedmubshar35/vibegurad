import 'package:flutter/material.dart';
import '../../../../models/location/location_models.dart';
import '../../../../services/location/geofencing_service.dart';

class GeofenceManagerWidget extends StatelessWidget {
  final List<JobSite> jobSites;
  final List<GeofenceEvent> geofenceEvents;
  final VoidCallback onCreateGeofence;
  final Function(JobSite) onEditJobSite;

  const GeofenceManagerWidget({
    super.key,
    required this.jobSites,
    required this.geofenceEvents,
    required this.onCreateGeofence,
    required this.onEditJobSite,
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
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Geofences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onCreateGeofence,
                  tooltip: 'Create Geofence',
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Active Geofences
            Text(
              'Active Job Sites (${jobSites.length})',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: jobSites.isEmpty
                  ? Center(
                      child: Text(
                        'No active geofences',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: jobSites.length,
                      itemBuilder: (context, index) {
                        final jobSite = jobSites[index];
                        return _buildJobSiteTile(jobSite);
                      },
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Recent Events
            Text(
              'Recent Events (${geofenceEvents.length})',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 150,
              child: geofenceEvents.isEmpty
                  ? Center(
                      child: Text(
                        'No recent events',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: geofenceEvents.length,
                      itemBuilder: (context, index) {
                        final event = geofenceEvents[index];
                        return _buildEventTile(event);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobSiteTile(JobSite jobSite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: jobSite.alertsEnabled ? Colors.green : Colors.grey,
          child: Icon(
            jobSite.type == GeofenceType.circle ? Icons.circle : Icons.crop_free,
            color: Colors.white,
            size: 16,
          ),
        ),
        title: Text(
          jobSite.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              jobSite.address,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                if (jobSite.authorizedWorkers.isNotEmpty)
                  Text(
                    '👥 ${jobSite.authorizedWorkers.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                if (jobSite.authorizedTools.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '🔧 ${jobSite.authorizedTools.length}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'view_events',
              child: Row(
                children: [
                  Icon(Icons.history, size: 16),
                  SizedBox(width: 8),
                  Text('View Events'),
                ],
              ),
            ),
            PopupMenuItem(
              value: jobSite.alertsEnabled ? 'disable_alerts' : 'enable_alerts',
              child: Row(
                children: [
                  Icon(
                    jobSite.alertsEnabled ? Icons.notifications_off : Icons.notifications,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(jobSite.alertsEnabled ? 'Disable Alerts' : 'Enable Alerts'),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleJobSiteAction(jobSite, value),
        ),
      ),
    );
  }

  Widget _buildEventTile(GeofenceEvent event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: event.isAuthorized ? null : Colors.red[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getEventColor(event),
          child: Icon(
            event.eventType == GeofenceEventType.enter ? Icons.login : Icons.logout,
            color: Colors.white,
            size: 16,
          ),
        ),
        title: Text(
          '${_capitalizeFirst(event.entityType)} ${event.eventType.name} ${event.jobSiteName}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entity: ${event.entityId}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              _formatTime(event.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: event.isAuthorized
            ? Icon(Icons.check_circle, color: Colors.green, size: 16)
            : Icon(Icons.warning, color: Colors.red, size: 16),
      ),
    );
  }

  Color _getEventColor(GeofenceEvent event) {
    if (!event.isAuthorized) return Colors.red;
    return event.eventType == GeofenceEventType.enter 
        ? Colors.green 
        : Colors.orange;
  }

  String _capitalizeFirst(String text) {
    return text.isNotEmpty 
        ? '${text[0].toUpperCase()}${text.substring(1)}'
        : text;
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _handleJobSiteAction(JobSite jobSite, String action) {
    switch (action) {
      case 'edit':
        onEditJobSite(jobSite);
        break;
      case 'view_events':
        // Navigate to events view
        break;
      case 'enable_alerts':
      case 'disable_alerts':
        // Toggle alerts
        break;
    }
  }
}