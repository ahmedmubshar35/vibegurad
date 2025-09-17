import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

@lazySingleton
class ConnectivityService with ListenableServiceMixin {
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  final Connectivity _connectivity = Connectivity();

  ConnectivityService() {
    listenToReactiveValues([_isConnected, _connectionType]);
  }

  // Reactive values
  final ReactiveValue<bool> _isConnected = ReactiveValue<bool>(true);
  final ReactiveValue<ConnectivityResult> _connectionType = 
      ReactiveValue<ConnectivityResult>(ConnectivityResult.none);

  bool get isConnected => _isConnected.value;
  ConnectivityResult get connectionType => _connectionType.value;

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Get initial connectivity status
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivityStatus,
        onError: (error) {
          _snackbarService.showSnackbar(
            message: 'Connectivity monitoring error: $error',
          );
        },
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to initialize connectivity service: $e',
      );
    }
  }

  // Update connectivity status
  void _updateConnectivityStatus(ConnectivityResult result) {
    final wasConnected = _isConnected.value;
    final isNowConnected = result != ConnectivityResult.none;

    _connectionType.value = result;
    _isConnected.value = isNowConnected;

    // Show notification when connectivity changes
    if (wasConnected != isNowConnected) {
      if (isNowConnected) {
        _snackbarService.showSnackbar(
          message: '🟢 Internet connection restored',
          duration: const Duration(seconds: 2),
        );
      } else {
        _snackbarService.showSnackbar(
          message: '🔴 No internet connection - working offline',
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  // Check if connected to WiFi
  bool get isWifiConnected => connectionType == ConnectivityResult.wifi;

  // Check if connected to mobile data
  bool get isMobileConnected => connectionType == ConnectivityResult.mobile;

  // Check if connected to ethernet
  bool get isEthernetConnected => connectionType == ConnectivityResult.ethernet;

  // Check if connected to any network
  bool get hasConnection => isConnected;

  // Get connection type as string
  String get connectionTypeString {
    switch (connectionType) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'None';
    }
  }

  // Dispose the service
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
