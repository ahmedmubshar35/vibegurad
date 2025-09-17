import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'history_viewmodel.dart';

class HistoryView extends StackedView<HistoryViewModel> {
  const HistoryView({super.key});

  @override
  Widget builder(BuildContext context, HistoryViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => viewModel.refreshHistory(),
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter and Statistics Section
                _buildFilterSection(context, viewModel),
                _buildStatisticsSection(context, viewModel),
                
                // Sessions List
                Expanded(
                  child: viewModel.filteredSessions.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          onRefresh: () => viewModel.refreshHistory(),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: viewModel.filteredSessions.length,
                            itemBuilder: (context, index) {
                              final session = viewModel.filteredSessions[index];
                              return _buildSessionItem(context, viewModel, session);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterSection(BuildContext context, HistoryViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: viewModel.availableFilters.map((filter) {
                final isSelected = viewModel.selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) => viewModel.setFilter(filter),
                    selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Date Range Selector
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showDateRangePicker(context, viewModel),
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    viewModel.selectedStartDate != null 
                        ? '${_formatDate(viewModel.selectedStartDate!)} - ${_formatDate(viewModel.selectedEndDate!)}'
                        : 'Select Date Range'
                  ),
                ),
              ),
              if (viewModel.selectedStartDate != null)
                IconButton(
                  onPressed: () => viewModel.setDateFilter(null, null),
                  icon: const Icon(Icons.clear),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(BuildContext context, HistoryViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              'Sessions',
              '${viewModel.totalSessions}',
              Icons.timer,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Total Exposure',
              '${viewModel.totalExposureMinutes}m',
              Icons.trending_up,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Warnings',
              '${viewModel.sessionsWithWarnings}',
              Icons.warning,
              Colors.yellow.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              context,
              'Alerts',
              '${viewModel.sessionsWithAlerts}',
              Icons.error,
              Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(BuildContext context, HistoryViewModel viewModel, session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: viewModel.getSessionStatusColor(session).withOpacity(0.1),
          child: Icon(
            _getSessionIcon(session),
            color: viewModel.getSessionStatusColor(session),
          ),
        ),
        title: Text(
          session.tool?.name ?? 'Unknown Tool',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Duration: ${session.formattedDuration}'),
            Text('Date: ${session.formattedDate}'),
            Text('Time: ${session.formattedStartTime} - ${session.formattedEndTime}'),
            if (session.hasWarnings || session.hasAlerts) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (session.hasWarnings)
                    Chip(
                      label: Text('${session.warnings.length} Warnings'),
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      labelStyle: TextStyle(color: Colors.orange.shade700, fontSize: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (session.hasAlerts)
                    Chip(
                      label: Text('${session.alerts.length} Alerts'),
                      backgroundColor: Colors.red.withOpacity(0.1),
                      labelStyle: const TextStyle(color: Colors.red, fontSize: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: viewModel.getSessionStatusColor(session),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            viewModel.getSessionStatusText(session),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => _showSessionDetails(context, session),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Sessions Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start using tools to see your session history here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getSessionIcon(session) {
    if (session.isEmergencyStopped) return Icons.emergency;
    if (session.hasAlerts) return Icons.error;
    if (session.hasWarnings) return Icons.warning;
    if (session.isCompleted) return Icons.check_circle;
    if (session.isActive) return Icons.play_circle;
    if (session.isPaused) return Icons.pause_circle;
    return Icons.stop_circle;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _showDateRangePicker(BuildContext context, HistoryViewModel viewModel) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: viewModel.selectedStartDate != null && viewModel.selectedEndDate != null
          ? DateTimeRange(start: viewModel.selectedStartDate!, end: viewModel.selectedEndDate!)
          : null,
    );
    
    if (picked != null) {
      viewModel.setDateFilter(picked.start, picked.end);
    }
  }

  void _showSessionDetails(BuildContext context, session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Tool', session.tool?.name ?? 'Unknown'),
            _buildDetailRow('Duration', session.formattedDuration),
            _buildDetailRow('Date', session.formattedDate),
            _buildDetailRow('Start Time', session.formattedStartTime),
            _buildDetailRow('End Time', session.formattedEndTime),
            _buildDetailRow('Status', session.status.toString().split('.').last),
            if (session.hasLocation)
              _buildDetailRow('Location', 'Lat: ${session.latitude}, Lng: ${session.longitude}'),
            if (session.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                'Notes:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(session.notes!),
            ],
            if (session.hasWarnings || session.hasAlerts) ...[
              const SizedBox(height: 12),
              Text(
                'Safety Events:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...session.warnings.map((warning) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(warning)),
                  ],
                ),
              )),
              ...session.alerts.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(alert)),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  HistoryViewModel viewModelBuilder(BuildContext context) => HistoryViewModel();
}
