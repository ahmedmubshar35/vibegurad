import 'package:flutter/material.dart';
import '../../../../models/location/location_models.dart';
import '../location_dashboard_view.dart';

class LocationMapWidget extends StatelessWidget {
  final MapViewType viewType;
  final List<ToolLocationData> toolLocations;
  final List<WorkerLocationData> workerLocations;
  final List<JobSite> jobSites;
  final List<VibrationHeatMapPoint> heatMapPoints;
  final Function(ToolLocationData) onToolTap;
  final Function(WorkerLocationData) onWorkerTap;
  final Function(JobSite) onJobSiteTap;

  const LocationMapWidget({
    super.key,
    required this.viewType,
    required this.toolLocations,
    required this.workerLocations,
    required this.jobSites,
    required this.heatMapPoints,
    required this.onToolTap,
    required this.onWorkerTap,
    required this.onJobSiteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          // Map placeholder - in a real app, this would be a map widget
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interactive Map View\n(${viewType.name.toUpperCase()})',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMapContent(),
                ],
              ),
            ),
          ),
          
          // Map controls
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _buildMapControlButton(Icons.zoom_in, () {}),
                const SizedBox(height: 8),
                _buildMapControlButton(Icons.zoom_out, () {}),
                const SizedBox(height: 8),
                _buildMapControlButton(Icons.my_location, () {}),
              ],
            ),
          ),
          
          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: _buildLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    switch (viewType) {
      case MapViewType.tools:
        return _buildToolsOverview();
      case MapViewType.workers:
        return _buildWorkersOverview();
      case MapViewType.heatmap:
        return _buildHeatMapOverview();
    }
  }

  Widget _buildToolsOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Active Tools: ${toolLocations.length}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (toolLocations.isNotEmpty) ...[
              Text('Recent locations:'),
              const SizedBox(height: 8),
              ...toolLocations.take(3).map((tool) => ListTile(
                leading: const Icon(Icons.build, color: Colors.blue),
                title: Text(tool.toolName),
                subtitle: Text(
                  'Last seen: ${_formatTime(tool.timestamp)}\n'
                  'Accuracy: ${tool.accuracy.toStringAsFixed(1)}m',
                ),
                trailing: Icon(
                  Icons.circle,
                  color: _getLocationStatusColor(tool.timestamp),
                  size: 12,
                ),
                onTap: () => onToolTap(tool),
              )),
            ] else ...[
              const Text('No active tools found'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWorkersOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Active Workers: ${workerLocations.length}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (workerLocations.isNotEmpty) ...[
              Text('Current status:'),
              const SizedBox(height: 8),
              ...workerLocations.take(3).map((worker) => ListTile(
                leading: Icon(
                  Icons.person,
                  color: worker.isWorking ? Colors.green : Colors.grey,
                ),
                title: Text(worker.workerName),
                subtitle: Text(
                  'Status: ${worker.isWorking ? 'Working' : 'Idle'}\n'
                  'Updated: ${_formatTime(worker.timestamp)}',
                ),
                trailing: Icon(
                  Icons.circle,
                  color: _getLocationStatusColor(worker.timestamp),
                  size: 12,
                ),
                onTap: () => onWorkerTap(worker),
              )),
            ] else ...[
              const Text('No active workers found'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMapOverview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Vibration Heat Map',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (heatMapPoints.isNotEmpty) ...[
              Text('Heat map points: ${heatMapPoints.length}'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildHeatMapStat(
                    'Max Vibration',
                    '${heatMapPoints.map((p) => p.vibrationLevel).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} m/s²',
                    Colors.red,
                  ),
                  _buildHeatMapStat(
                    'Avg Vibration',
                    '${(heatMapPoints.map((p) => p.vibrationLevel).reduce((a, b) => a + b) / heatMapPoints.length).toStringAsFixed(1)} m/s²',
                    Colors.orange,
                  ),
                  _buildHeatMapStat(
                    'Total Points',
                    heatMapPoints.length.toString(),
                    Colors.blue,
                  ),
                ],
              ),
            ] else ...[
              const Text('No heat map data available'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Generate Heat Map'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeatMapStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlButton(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ..._getLegendItems().map((item) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                item.icon,
                color: item.color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                item.label,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          )),
        ],
      ),
    );
  }

  List<LegendItem> _getLegendItems() {
    switch (viewType) {
      case MapViewType.tools:
        return [
          LegendItem(Icons.build, Colors.blue, 'Active Tool'),
          LegendItem(Icons.circle, Colors.green, 'Recent'),
          LegendItem(Icons.circle, Colors.orange, 'Stale'),
          LegendItem(Icons.circle, Colors.red, 'Offline'),
        ];
      case MapViewType.workers:
        return [
          LegendItem(Icons.person, Colors.green, 'Working'),
          LegendItem(Icons.person, Colors.grey, 'Idle'),
          LegendItem(Icons.circle, Colors.green, 'Recent'),
          LegendItem(Icons.circle, Colors.red, 'Offline'),
        ];
      case MapViewType.heatmap:
        return [
          LegendItem(Icons.circle, Colors.green, 'Low (0-2.5)'),
          LegendItem(Icons.circle, Colors.yellow, 'Medium (2.5-5)'),
          LegendItem(Icons.circle, Colors.orange, 'High (5-8)'),
          LegendItem(Icons.circle, Colors.red, 'Critical (8+)'),
        ];
    }
  }

  Color _getLocationStatusColor(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes <= 5) return Colors.green;
    if (difference.inMinutes <= 30) return Colors.orange;
    return Colors.red;
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

class LegendItem {
  final IconData icon;
  final Color color;
  final String label;

  LegendItem(this.icon, this.color, this.label);
}