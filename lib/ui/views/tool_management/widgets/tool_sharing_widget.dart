import 'package:flutter/material.dart';

class ToolSharingWidget extends StatelessWidget {
  final List<Map<String, dynamic>> incomingRequests;
  final List<Map<String, dynamic>> outgoingRequests;
  final List<Map<String, dynamic>> activeSharing;
  final VoidCallback onRequestSharing;
  final Function(Map<String, dynamic>) onApproveSharing;
  final Function(Map<String, dynamic>) onRejectSharing;

  const ToolSharingWidget({
    super.key,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.activeSharing,
    required this.onRequestSharing,
    required this.onApproveSharing,
    required this.onRejectSharing,
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
                'Tool Sharing',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onRequestSharing,
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Request Tool'),
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
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Incoming'),
                      Tab(text: 'Outgoing'),
                      Tab(text: 'Active'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildIncomingTab(),
                        _buildOutgoingTab(),
                        _buildActiveTab(),
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

  Widget _buildIncomingTab() {
    return ListView.builder(
      itemCount: incomingRequests.length,
      itemBuilder: (context, index) {
        final request = incomingRequests[index];
        return Card(
          child: ListTile(
            title: Text('Request from ${request['requestingTeamName'] ?? 'Unknown Team'}'),
            subtitle: Text('Tool: ${request['toolName'] ?? 'Unknown Tool'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => onApproveSharing(request),
                  icon: const Icon(Icons.check, color: Colors.green),
                ),
                IconButton(
                  onPressed: () => onRejectSharing(request),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutgoingTab() {
    return ListView.builder(
      itemCount: outgoingRequests.length,
      itemBuilder: (context, index) {
        final request = outgoingRequests[index];
        return Card(
          child: ListTile(
            title: Text('Request to ${request['requestedFromTeamName'] ?? 'Unknown Team'}'),
            subtitle: Text('Tool: ${request['toolName'] ?? 'Unknown Tool'}'),
            trailing: Chip(
              label: Text(request['status'] ?? 'pending'),
              backgroundColor: _getStatusColor(request['status']),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTab() {
    return ListView.builder(
      itemCount: activeSharing.length,
      itemBuilder: (context, index) {
        final sharing = activeSharing[index];
        return Card(
          child: ListTile(
            title: Text('Sharing with ${sharing['teamName'] ?? 'Unknown Team'}'),
            subtitle: Text('Tool: ${sharing['toolName'] ?? 'Unknown Tool'}'),
            trailing: const Icon(Icons.swap_horiz, color: Colors.blue),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
}