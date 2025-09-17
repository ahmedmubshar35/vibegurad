import 'package:flutter/material.dart';
import '../../../../models/location/location_models.dart';
import '../../../../services/location/vibration_heatmap_service.dart';

class HeatMapWidget extends StatelessWidget {
  final List<VibrationHeatMapPoint> heatMapPoints;
  final List<VibrationHotSpot> hotSpots;
  final Function(VibrationHotSpot) onHotSpotTap;
  final VoidCallback onGenerateReport;

  const HeatMapWidget({
    super.key,
    required this.heatMapPoints,
    required this.hotSpots,
    required this.onHotSpotTap,
    required this.onGenerateReport,
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
                const Icon(Icons.whatshot, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Vibration Heat Map Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onGenerateReport,
                  icon: const Icon(Icons.assessment, size: 16),
                  label: const Text('Generate Report'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Heat Map Statistics
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Points',
                    heatMapPoints.length.toString(),
                    Icons.scatter_plot,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Hot Spots',
                    hotSpots.length.toString(),
                    Icons.warning,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Max Vibration',
                    heatMapPoints.isNotEmpty
                        ? '${heatMapPoints.map((p) => p.vibrationLevel).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} m/s²'
                        : '0.0 m/s²',
                    Icons.speed,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Avg Exposure',
                    heatMapPoints.isNotEmpty
                        ? '${(heatMapPoints.map((p) => p.exposureTime).reduce((a, b) => a + b) / heatMapPoints.length).toStringAsFixed(0)} min'
                        : '0 min',
                    Icons.timer,
                    Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Hot Spots List
            Row(
              children: [
                const Text(
                  'Critical Hot Spots',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                if (hotSpots.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hotSpots.where((h) => h.severity == 'critical').length.toString(),
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 250,
              child: hotSpots.isEmpty
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
                            'No critical hot spots detected',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: hotSpots.length,
                      itemBuilder: (context, index) {
                        final hotSpot = hotSpots[index];
                        return _buildHotSpotTile(hotSpot);
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Heat Map Intensity Legend
            _buildIntensityLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHotSpotTile(VibrationHotSpot hotSpot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: _getSeverityColor(hotSpot.severity).withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRiskLevelColor(hotSpot.riskLevel),
          child: Icon(
            Icons.warning,
            color: Colors.white,
            size: 16,
          ),
        ),
        title: Text(
          'Vibration: ${hotSpot.vibrationLevel.toStringAsFixed(1)} m/s²',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location: ${hotSpot.latitude.toStringAsFixed(4)}, ${hotSpot.longitude.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Exposure: ${hotSpot.exposureTime.toStringAsFixed(0)} min • Sessions: ${hotSpot.sessionCount}',
              style: const TextStyle(fontSize: 12),
            ),
            if (hotSpot.toolsUsed.isNotEmpty)
              Text(
                'Tools: ${hotSpot.toolsUsed.join(', ')}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getSeverityColor(hotSpot.severity),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                hotSpot.severity.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hotSpot.riskLevel.name.toUpperCase(),
              style: TextStyle(
                fontSize: 8,
                color: _getRiskLevelColor(hotSpot.riskLevel),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        onTap: () => onHotSpotTap(hotSpot),
      ),
    );
  }

  Widget _buildIntensityLegend() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vibration Intensity Legend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Low', '0-2.5', Colors.green),
              _buildLegendItem('Medium', '2.5-5.0', Colors.yellow[700]!),
              _buildLegendItem('High', '5.0-8.0', Colors.orange),
              _buildLegendItem('Critical', '8.0+', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String range, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
        Text(
          '$range m/s²',
          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
        ),
      ],
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
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getRiskLevelColor(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.critical:
        return Colors.red[800]!;
      case RiskLevel.high:
        return Colors.red[600]!;
      case RiskLevel.medium:
        return Colors.orange[600]!;
      case RiskLevel.low:
        return Colors.green[600]!;
    }
  }
}