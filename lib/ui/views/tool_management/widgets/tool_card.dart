import 'package:flutter/material.dart';
import '../../../../models/tool/tool.dart';

class ToolCard extends StatelessWidget {
  final Tool tool;
  final VoidCallback? onTap;
  final VoidCallback? onToggleAvailability;
  final VoidCallback? onScheduleMaintenance;
  final VoidCallback? onDelete;
  final bool showActions;

  const ToolCard({
    super.key,
    required this.tool,
    this.onTap,
    this.onToggleAvailability,
    this.onScheduleMaintenance,
    this.onDelete,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Tool Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.build,
                      color: _getStatusColor(),
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Tool Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tool.brand} • ${tool.model}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Actions Menu
                  if (showActions)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'toggle':
                            onToggleAvailability?.call();
                            break;
                          case 'maintenance':
                            onScheduleMaintenance?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Icon(tool.isToolActive ? Icons.visibility_off : Icons.visibility),
                              const SizedBox(width: 8),
                              Text(tool.isToolActive ? 'Disable' : 'Enable'),
                            ],
                          ),
                        ),
                        if (!tool.needsMaintenance)
                          const PopupMenuItem(
                            value: 'maintenance',
                            child: Row(
                              children: [
                                Icon(Icons.build_circle),
                                SizedBox(width: 8),
                                Text('Schedule Maintenance'),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              const Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Details Row
              Row(
                children: [
                  Expanded(
                    child: _buildDetailChip(
                      context,
                      Icons.category,
                      tool.category,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailChip(
                      context,
                      Icons.vibration,
                      '${tool.vibrationLevel.toStringAsFixed(1)} m/s²',
                      _getVibrationRiskColor(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDetailChip(
                      context,
                      Icons.timer,
                      '${tool.dailyExposureLimit}m limit',
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Last Used Info
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getLastUsedText(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (tool.assignedWorkerId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Assigned',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // Warning Indicators
              if (tool.needsMaintenance || !tool.isToolActive) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tool.needsMaintenance 
                        ? Colors.orange.withValues(alpha: 0.1) 
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: tool.needsMaintenance ? Colors.orange : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        tool.needsMaintenance ? Icons.warning : Icons.block,
                        size: 16,
                        color: tool.needsMaintenance ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tool.needsMaintenance 
                              ? 'Maintenance required - tool may be unsafe to use'
                              : 'Tool is currently disabled',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tool.needsMaintenance 
                                ? const Color(0xFFE65100) 
                                : const Color(0xFF616161),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!tool.isToolActive) return Colors.grey;
    if (tool.needsMaintenance) return Colors.orange;
    if (tool.assignedWorkerId != null) return Colors.blue;
    return Colors.green;
  }

  String _getStatusText() {
    if (!tool.isToolActive) return 'Disabled';
    if (tool.needsMaintenance) return 'Maintenance';
    if (tool.assignedWorkerId != null) return 'Assigned';
    return 'Available';
  }

  Color _getVibrationRiskColor() {
    final vibration = tool.vibrationLevel;
    if (vibration < 2.5) return Colors.green;
    if (vibration < 5.0) return Colors.blue;
    if (vibration < 10.0) return Colors.orange;
    return Colors.red;
  }

  String _getLastUsedText() {
    if (tool.lastMaintenanceDate == null) {
      return 'No maintenance recorded';
    }
    
    final now = DateTime.now();
    final difference = now.difference(tool.lastMaintenanceDate!);
    
    if (difference.inDays > 0) {
      return 'Last maintenance ${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return 'Last maintenance ${difference.inHours} hours ago';
    } else {
      return 'Recently maintained';
    }
  }
}