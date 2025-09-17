import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'offline_mode_viewmodel.dart';

class OfflineModeView extends StatelessWidget {
  const OfflineModeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<OfflineModeViewModel>.reactive(
      viewModelBuilder: () => OfflineModeViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Offline Mode'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: viewModel.syncData,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection Status
                _buildConnectionStatus(context, viewModel),
                const SizedBox(height: 24),
                
                // Offline Data
                _buildOfflineData(context, viewModel),
                const SizedBox(height: 24),
                
                // Sync Settings
                _buildSyncSettings(context, viewModel),
                const SizedBox(height: 24),
                
                // Data Queue
                _buildDataQueue(context, viewModel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(BuildContext context, OfflineModeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  viewModel.isConnected ? Icons.wifi : Icons.wifi_off,
                  color: viewModel.isConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        viewModel.isConnected ? 'Connected' : 'Offline',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: viewModel.isConnected ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: viewModel.isConnected 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    viewModel.connectionTypeString,
                    style: TextStyle(
                      color: viewModel.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!viewModel.isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Working offline. Data will sync when connection is restored.',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineData(BuildContext context, OfflineModeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Offline Data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDataItem(
                    context,
                    'Pending Sync',
                    '${viewModel.pendingSyncCount} items',
                    Icons.sync,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataItem(
                    context,
                    'Last Sync',
                    viewModel.lastSyncTime,
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDataItem(
                    context,
                    'Offline Storage',
                    '${viewModel.offlineStorageSize} MB',
                    Icons.storage,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDataItem(
                    context,
                    'Sync Status',
                    viewModel.syncStatus,
                    Icons.cloud_sync,
                    viewModel.isSyncing ? Colors.blue : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSyncSettings(BuildContext context, OfflineModeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto Sync'),
              subtitle: const Text('Automatically sync when connected'),
              value: viewModel.autoSyncEnabled,
              onChanged: viewModel.setAutoSync,
              secondary: const Icon(Icons.sync),
            ),
            SwitchListTile(
              title: const Text('WiFi Only Sync'),
              subtitle: const Text('Only sync when connected to WiFi'),
              value: viewModel.wifiOnlySync,
              onChanged: viewModel.setWifiOnlySync,
              secondary: const Icon(Icons.wifi),
            ),
            SwitchListTile(
              title: const Text('Background Sync'),
              subtitle: const Text('Sync data in the background'),
              value: viewModel.backgroundSyncEnabled,
              onChanged: viewModel.setBackgroundSync,
              secondary: const Icon(Icons.sync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataQueue(BuildContext context, OfflineModeViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Data Queue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (viewModel.pendingSyncCount > 0)
                  ElevatedButton.icon(
                    onPressed: viewModel.syncData,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (viewModel.pendingSyncCount == 0)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 48,
                      color: Colors.green.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All data synced',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: viewModel.pendingSyncCount,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.pending),
                    title: Text('Sync Item ${index + 1}'),
                    subtitle: const Text('Waiting to sync'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
