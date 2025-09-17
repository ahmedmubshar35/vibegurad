import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolCheckoutWidget extends StatelessWidget {
  final List<ToolCheckout> checkouts;
  final List<ToolCheckout> overdueCheckouts;
  final VoidCallback onCheckout;
  final Function(ToolCheckout) onCheckin;
  final Function(ToolCheckout) onExtend;

  const ToolCheckoutWidget({
    super.key,
    required this.checkouts,
    required this.overdueCheckouts,
    required this.onCheckout,
    required this.onCheckin,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Tool Checkouts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCheckout,
                icon: const Icon(Icons.assignment_return, size: 16),
                label: const Text('Check Out'),
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
          if (overdueCheckouts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${overdueCheckouts.length} overdue checkout${overdueCheckouts.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Checkout list
          Expanded(
            child: checkouts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_return_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active checkouts',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: onCheckout,
                          child: const Text('Check Out Tool'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: checkouts.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final checkout = checkouts[index];
                      return _buildCheckoutItem(checkout);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutItem(ToolCheckout checkout) {
    final isOverdue = checkout.isOverdue;
    final daysOut = DateTime.now().difference(checkout.checkoutTime).inDays;
    
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: isOverdue 
              ? Border.all(color: Colors.red[300]!, width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Checkout details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Checkout #${checkout.checkoutId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'OVERDUE',
                              style: TextStyle(
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
                      'Checked out to: ${checkout.workerName}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    
                    Text(
                      'Site: ${checkout.jobSiteName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$daysOut day${daysOut == 1 ? '' : 's'} out',
                          style: TextStyle(
                            color: isOverdue ? Colors.red[700] : Colors.grey[600],
                            fontSize: 11,
                            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (checkout.expectedReturnTime != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Due: ${_formatDate(checkout.expectedReturnTime!)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions
              Column(
                children: [
                  IconButton(
                    onPressed: () => onCheckin(checkout),
                    icon: Icon(
                      Icons.assignment_turned_in,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    tooltip: 'Check In',
                  ),
                  IconButton(
                    onPressed: () => onExtend(checkout),
                    icon: Icon(
                      Icons.schedule,
                      color: Colors.orange[600],
                      size: 20,
                    ),
                    tooltip: 'Extend',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}