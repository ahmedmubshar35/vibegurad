import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolInventoryWidget extends StatelessWidget {
  final List<ToolInventory> inventory;
  final Function(ToolInventory) onItemTap;
  final VoidCallback onAddItem;
  final Function(ToolInventory) onEditItem;

  const ToolInventoryWidget({
    super.key,
    required this.inventory,
    required this.onItemTap,
    required this.onAddItem,
    required this.onEditItem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with actions
          Row(
            children: [
              const Text(
                'Tool Inventory',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildStatusCount('Available', _getStatusCount(ToolStatus.available), Colors.green),
                const SizedBox(width: 16),
                _buildStatusCount('Checked Out', _getStatusCount(ToolStatus.checkedOut), Colors.orange),
                const SizedBox(width: 16),
                _buildStatusCount('Maintenance', _getStatusCount(ToolStatus.maintenance), Colors.red),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Inventory list
          Expanded(
            child: inventory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No inventory items found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: onAddItem,
                          child: const Text('Add First Item'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: inventory.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = inventory[index];
                      return _buildInventoryItem(item, context);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCount(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  int _getStatusCount(ToolStatus status) {
    return inventory.where((item) => item.status == status).length;
  }

  Widget _buildInventoryItem(ToolInventory item, BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onItemTap(item),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Tool icon/image
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(item.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getToolIcon(item.category),
                  color: _getStatusColor(item.status),
                  size: 24,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Tool details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.toolName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(item.status),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.status.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${item.brand} ${item.model}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          item.currentLocation,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.inventory,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (item.quantity <= item.minStockLevel)
                          Icon(
                            Icons.warning,
                            size: 16,
                            color: Colors.orange[600],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              PopupMenuButton<String>(
                onSelected: (action) => _handleItemAction(action, item),
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
                    value: 'view_history',
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16),
                        SizedBox(width: 8),
                        Text('View History'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'update_status',
                    child: Row(
                      children: [
                        Icon(Icons.update, size: 16),
                        SizedBox(width: 8),
                        Text('Update Status'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ToolStatus status) {
    switch (status) {
      case ToolStatus.available:
        return Colors.green;
      case ToolStatus.checkedOut:
        return Colors.orange;
      case ToolStatus.maintenance:
        return Colors.red;
      case ToolStatus.repair:
        return Colors.red;
      case ToolStatus.outOfService:
        return Colors.grey;
      case ToolStatus.retired:
        return Colors.grey[700]!;
      case ToolStatus.reserved:
        return Colors.blue;
    }
  }

  IconData _getToolIcon(String category) {
    switch (category.toLowerCase()) {
      case 'drill':
        return Icons.build;
      case 'saw':
        return Icons.carpenter;
      case 'hammer':
        return Icons.hardware;
      case 'wrench':
        return Icons.build_circle;
      case 'power tools':
        return Icons.electrical_services;
      case 'hand tools':
        return Icons.handyman;
      case 'measuring':
        return Icons.straighten;
      case 'safety':
        return Icons.safety_check;
      default:
        return Icons.construction;
    }
  }

  void _handleItemAction(String action, ToolInventory item) {
    switch (action) {
      case 'edit':
        onEditItem(item);
        break;
      case 'view_history':
        // Handle view history
        break;
      case 'update_status':
        // Handle update status
        break;
    }
  }
}