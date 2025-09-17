import 'package:flutter/material.dart';
import '../../../../models/tool/advanced_tool_models.dart';

class ToolReservationsWidget extends StatelessWidget {
  final List<ToolReservation> reservations;
  final List<ToolReservation> pendingApprovals;
  final VoidCallback onCreateReservation;
  final Function(ToolReservation) onApproveReservation;
  final Function(ToolReservation) onRejectReservation;

  const ToolReservationsWidget({
    super.key,
    required this.reservations,
    required this.pendingApprovals,
    required this.onCreateReservation,
    required this.onApproveReservation,
    required this.onRejectReservation,
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
                'Tool Reservations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onCreateReservation,
                icon: const Icon(Icons.event, size: 16),
                label: const Text('Reserve Tool'),
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
          
          // Pending approvals section
          if (pendingApprovals.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.pending_actions, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${pendingApprovals.length} reservation${pendingApprovals.length == 1 ? '' : 's'} need${pendingApprovals.length == 1 ? 's' : ''} approval',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Pending approvals list
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pending Approvals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...pendingApprovals.map((reservation) => 
                  _buildPendingReservationItem(reservation)
                ),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Upcoming reservations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Reservations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                Expanded(
                  child: reservations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No upcoming reservations',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: onCreateReservation,
                                child: const Text('Create Reservation'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: reservations.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final reservation = reservations[index];
                            return _buildReservationItem(reservation);
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingReservationItem(ToolReservation reservation) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Priority indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _getPriorityColor(reservation.priority),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Reservation details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Reservation #${reservation.reservationId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(reservation.priority),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            reservation.priority.name.toUpperCase(),
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
                      'Requested by: ${reservation.workerName}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    
                    Text(
                      '${_formatDateTime(reservation.reservationStart)} - ${_formatDateTime(reservation.reservationEnd)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Approval actions
              Row(
                children: [
                  IconButton(
                    onPressed: () => onApproveReservation(reservation),
                    icon: Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    tooltip: 'Approve',
                  ),
                  IconButton(
                    onPressed: () => onRejectReservation(reservation),
                    icon: Icon(
                      Icons.cancel,
                      color: Colors.red[600],
                      size: 20,
                    ),
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReservationItem(ToolReservation reservation) {
    final daysUntilStart = reservation.reservationStart.difference(DateTime.now()).inDays;
    final isStartingSoon = daysUntilStart <= 1;
    
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: _getStatusColor(reservation.status),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Reservation details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reservation #${reservation.reservationId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isStartingSoon)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            daysUntilStart == 0 ? 'TODAY' : 'TOMORROW',
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
                    'Reserved by: ${reservation.workerName}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  
                  if (reservation.projectId != null)
                    Text(
                      'Project: ${reservation.projectId}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  
                  const SizedBox(height: 4),
                  
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${_formatDateTime(reservation.reservationStart)} - ${_formatDateTime(reservation.reservationEnd)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Status indicator
            Icon(
              _getStatusIcon(reservation.status),
              color: _getStatusColor(reservation.status),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(ReservationPriority priority) {
    switch (priority) {
      case ReservationPriority.low:
        return Colors.green;
      case ReservationPriority.normal:
        return Colors.blue;
      case ReservationPriority.high:
        return Colors.orange;
      case ReservationPriority.urgent:
        return Colors.red;
    }
  }

  Color _getStatusColor(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return Colors.orange;
      case ReservationStatus.approved:
        return Colors.blue;
      case ReservationStatus.active:
        return Colors.green;
      case ReservationStatus.completed:
        return Colors.grey;
      case ReservationStatus.cancelled:
        return Colors.red;
      case ReservationStatus.expired:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ReservationStatus status) {
    switch (status) {
      case ReservationStatus.pending:
        return Icons.pending;
      case ReservationStatus.approved:
        return Icons.check_circle;
      case ReservationStatus.active:
        return Icons.play_circle;
      case ReservationStatus.completed:
        return Icons.check_circle_outline;
      case ReservationStatus.cancelled:
        return Icons.cancel;
      case ReservationStatus.expired:
        return Icons.schedule;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}