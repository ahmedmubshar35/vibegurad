import 'package:flutter/material.dart';

class AdvancedToolOverviewWidget extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Function(String) onStatsTap;

  const AdvancedToolOverviewWidget({
    super.key,
    required this.stats,
    required this.onStatsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tool Management Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          
          // Key metrics grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildMetricCard(
                'Total Inventory',
                '${stats['inventory']?['totalItems'] ?? 0}',
                Icons.inventory,
                Colors.green,
                'inventory',
              ),
              _buildMetricCard(
                'Active Checkouts',
                '${stats['checkouts']?['activeCheckouts'] ?? 0}',
                Icons.assignment_return,
                Colors.orange,
                'checkouts',
              ),
              _buildMetricCard(
                'Pending Reservations',
                '${stats['reservations']?['pendingRequests'] ?? 0}',
                Icons.schedule,
                Colors.purple,
                'reservations',
              ),
              _buildMetricCard(
                'Tools Needing Action',
                '${stats['conditions']?['requiresActionCount'] ?? 0}',
                Icons.warning,
                Colors.red,
                'conditions',
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Additional stats row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Performance Score',
                  '${(stats['performance']?['performanceScore'] ?? 0.0).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  Colors.blue[300]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Warranty Expiring',
                  '${stats['warranties']?['expiringWarranties'] ?? 0}',
                  Icons.security,
                  Colors.yellow[300]!,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  'Total Value',
                  '\$${_formatCurrency(stats['inventory']?['totalValue'] ?? 0.0)}',
                  Icons.attach_money,
                  Colors.green[300]!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String statType,
  ) {
    return GestureDetector(
      onTap: () => onStatsTap(statType),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}