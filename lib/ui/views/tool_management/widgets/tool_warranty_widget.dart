import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolWarrantyWidget extends StatelessWidget {
  final List<ToolWarranty> expiringWarranties;
  final List<ToolWarranty> activeWarranties;
  final List<Map<String, dynamic>> renewalRecommendations;
  final VoidCallback onCreateWarranty;
  final Function(ToolWarranty) onExtendWarranty;
  final Function(ToolWarranty) onCreateClaim;

  const ToolWarrantyWidget({
    super.key,
    required this.expiringWarranties,
    required this.activeWarranties,
    required this.renewalRecommendations,
    required this.onCreateWarranty,
    required this.onExtendWarranty,
    required this.onCreateClaim,
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
                'Warranty Management',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCreateWarranty,
                icon: const Icon(Icons.security, size: 16),
                label: const Text('Add Warranty'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (expiringWarranties.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[300]!),
              ),
              child: Text(
                '${expiringWarranties.length} warranties expiring soon',
                style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w600),
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
                      Tab(text: 'Active'),
                      Tab(text: 'Expiring'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildActiveTab(),
                        _buildExpiringTab(),
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

  Widget _buildActiveTab() {
    return ListView.builder(
      itemCount: activeWarranties.length,
      itemBuilder: (context, index) {
        final warranty = activeWarranties[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: const Icon(Icons.shield, color: Colors.white, size: 16),
            ),
            title: Text('Warranty #${warranty.warrantyNumber}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider: ${warranty.warrantyProvider}'),
                Text('Expires: ${_formatDate(warranty.endDate)}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'extend':
                    onExtendWarranty(warranty);
                    break;
                  case 'claim':
                    onCreateClaim(warranty);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'extend',
                  child: Text('Extend'),
                ),
                const PopupMenuItem(
                  value: 'claim',
                  child: Text('Create Claim'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiringTab() {
    return ListView.builder(
      itemCount: expiringWarranties.length,
      itemBuilder: (context, index) {
        final warranty = expiringWarranties[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: const Icon(Icons.schedule, color: Colors.white, size: 16),
            ),
            title: Text('Warranty #${warranty.warrantyNumber}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider: ${warranty.warrantyProvider}'),
                Text('Expires: ${_formatDate(warranty.endDate)}'),
                Text('Days left: ${warranty.daysUntilExpiry}'),
              ],
            ),
            trailing: IconButton(
              onPressed: () => onExtendWarranty(warranty),
              icon: const Icon(Icons.extension, color: Colors.blue),
              tooltip: 'Extend Warranty',
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}