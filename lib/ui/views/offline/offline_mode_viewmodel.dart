import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/core/connectivity_service.dart';
import '../../../services/core/notification_manager.dart';

class OfflineModeViewModel extends BaseViewModel {
  final _connectivityService = locator<ConnectivityService>();
  final _snackbarService = locator<SnackbarService>();
  
  bool _autoSyncEnabled = true;
  bool _wifiOnlySync = false;
  bool _backgroundSyncEnabled = true;
  bool _isSyncing = false;
  int _pendingSyncCount = 5; // Simulated
  String _lastSyncTime = '2 hours ago';
  String _offlineStorageSize = '12.5';
  
  bool get isConnected => _connectivityService.isConnected;
  String get connectionTypeString => _connectivityService.connectionTypeString;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get wifiOnlySync => _wifiOnlySync;
  bool get backgroundSyncEnabled => _backgroundSyncEnabled;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  String get lastSyncTime => _lastSyncTime;
  String get offlineStorageSize => _offlineStorageSize;
  
  String get syncStatus {
    if (_isSyncing) return 'Syncing...';
    if (!isConnected) return 'Offline';
    if (_pendingSyncCount > 0) return 'Pending';
    return 'Up to date';
  }
  
  void setAutoSync(bool enabled) {
    _autoSyncEnabled = enabled;
    notifyListeners();
  }
  
  void setWifiOnlySync(bool enabled) {
    _wifiOnlySync = enabled;
    notifyListeners();
  }
  
  void setBackgroundSync(bool enabled) {
    _backgroundSyncEnabled = enabled;
    notifyListeners();
  }
  
  Future<void> syncData() async {
    if (!isConnected) {
      NotificationManager().showWarning('No internet connection available');
      return;
    }
    
    setBusy(true);
    _isSyncing = true;
    notifyListeners();
    
    try {
      // Simulate sync process
      await Future.delayed(const Duration(seconds: 3));
      
      _pendingSyncCount = 0;
      _lastSyncTime = 'Just now';
      _isSyncing = false;
      
      NotificationManager().showSuccess('Data synced successfully');
    } catch (e) {
      _isSyncing = false;
      NotificationManager().showError('Sync failed: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }
}














