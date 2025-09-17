import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../models/location/location_models.dart';
import '../../../services/location/tool_location_service.dart';
import '../../../services/location/worker_location_service.dart';
import '../../../services/location/geofencing_service.dart';
import '../../../services/location/vibration_heatmap_service.dart';
import '../../../services/location/tool_proximity_service.dart';
import 'widgets/location_map_widget.dart';
import 'widgets/geofence_manager_widget.dart';
import 'widgets/proximity_alerts_widget.dart';
import 'widgets/heat_map_widget.dart';
import 'widgets/location_statistics_widget.dart';

class LocationDashboardView extends StatelessWidget {
  const LocationDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<LocationDashboardViewModel>.reactive(
      viewModelBuilder: () => LocationDashboardViewModel(),
      onViewModelReady: (model) => model.initialize(),
      builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('📍 Location Services'),
            backgroundColor: Colors.blue[800],
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: model.refresh,
                tooltip: 'Refresh Data',
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(context, model, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export_locations',
                    child: Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Export Location Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'create_geofence',
                    child: Row(
                      children: [
                        Icon(Icons.add_location),
                        SizedBox(width: 8),
                        Text('Create Geofence'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'proximity_settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Proximity Settings'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: model.isBusy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Statistics Summary
                      LocationStatisticsWidget(
                        toolCount: model.toolLocations.length,
                        workerCount: model.workerLocations.length,
                        activeGeofences: model.activeJobSites.length,
                        pendingAlerts: model.proximityAlerts.where((a) => !a.acknowledged).length,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Main Location Map
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.map, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Location Map',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  SegmentedButton<MapViewType>(
                                    segments: const [
                                      ButtonSegment(
                                        value: MapViewType.tools,
                                        label: Text('Tools'),
                                        icon: Icon(Icons.build, size: 16),
                                      ),
                                      ButtonSegment(
                                        value: MapViewType.workers,
                                        label: Text('Workers'),
                                        icon: Icon(Icons.person, size: 16),
                                      ),
                                      ButtonSegment(
                                        value: MapViewType.heatmap,
                                        label: Text('Heat Map'),
                                        icon: Icon(Icons.whatshot, size: 16),
                                      ),
                                    ],
                                    selected: {model.selectedMapView},
                                    onSelectionChanged: (Set<MapViewType> selection) {
                                      model.changeMapView(selection.first);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 400,
                                child: LocationMapWidget(
                                  viewType: model.selectedMapView,
                                  toolLocations: model.toolLocations,
                                  workerLocations: model.workerLocations,
                                  jobSites: model.activeJobSites,
                                  heatMapPoints: model.heatMapPoints,
                                  onToolTap: (tool) => _showToolDetails(context, tool),
                                  onWorkerTap: (worker) => _showWorkerDetails(context, worker),
                                  onJobSiteTap: (jobSite) => _showJobSiteDetails(context, jobSite),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Proximity Alerts & Geofences
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Proximity Alerts
                          Expanded(
                            flex: 1,
                            child: ProximityAlertsWidget(
                              alerts: model.proximityAlerts,
                              onAlertTap: (alert) => _showAlertDetails(context, alert),
                              onAcknowledge: model.acknowledgeAlert,
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          // Geofence Manager
                          Expanded(
                            flex: 1,
                            child: GeofenceManagerWidget(
                              jobSites: model.activeJobSites,
                              geofenceEvents: model.recentGeofenceEvents,
                              onCreateGeofence: () => _createGeofence(context, model),
                              onEditJobSite: (jobSite) => _editJobSite(context, jobSite),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Heat Map Analysis
                      if (model.selectedMapView == MapViewType.heatmap)
                        HeatMapWidget(
                          heatMapPoints: model.heatMapPoints,
                          hotSpots: model.hotSpots,
                          onHotSpotTap: (hotSpot) => _showHotSpotDetails(context, hotSpot),
                          onGenerateReport: () => _generateHeatMapReport(context, model),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _handleMenuAction(BuildContext context, LocationDashboardViewModel model, String action) {
    switch (action) {
      case 'export_locations':
        _exportLocationData(context, model);
        break;
      case 'create_geofence':
        _createGeofence(context, model);
        break;
      case 'proximity_settings':
        _showProximitySettings(context, model);
        break;
    }
  }

  void _showToolDetails(BuildContext context, ToolLocationData tool) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tool: ${tool.toolName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${tool.latitude.toStringAsFixed(6)}, ${tool.longitude.toStringAsFixed(6)}'),
            Text('Last Updated: ${_formatDateTime(tool.timestamp)}'),
            Text('Accuracy: ${tool.accuracy.toStringAsFixed(1)}m'),
            if (tool.workerId != null) Text('Used by: ${tool.workerId}'),
            if (tool.jobSiteId != null) Text('Job Site: ${tool.jobSiteId}'),
            if (tool.address != null) Text('Address: ${tool.address}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/tool-details', arguments: tool.toolId);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _showWorkerDetails(BuildContext context, WorkerLocationData worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Worker: ${worker.workerName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${worker.latitude.toStringAsFixed(6)}, ${worker.longitude.toStringAsFixed(6)}'),
            Text('Last Updated: ${_formatDateTime(worker.timestamp)}'),
            Text('Accuracy: ${worker.accuracy.toStringAsFixed(1)}m'),
            Text('Working: ${worker.isWorking ? 'Yes' : 'No'}'),
            if (worker.currentToolId != null) Text('Current Tool: ${worker.currentToolId}'),
            if (worker.jobSiteId != null) Text('Job Site: ${worker.jobSiteId}'),
            if (worker.sessionId != null) Text('Session: ${worker.sessionId}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/worker-profile', arguments: worker.workerId);
            },
            child: const Text('View Profile'),
          ),
        ],
      ),
    );
  }

  void _showJobSiteDetails(BuildContext context, JobSite jobSite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Job Site: ${jobSite.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Description: ${jobSite.description}'),
            Text('Address: ${jobSite.address}'),
            Text('Type: ${jobSite.type.name.toUpperCase()}'),
            if (jobSite.radius != null) Text('Radius: ${jobSite.radius!.toStringAsFixed(1)}m'),
            Text('Authorized Workers: ${jobSite.authorizedWorkers.length}'),
            Text('Authorized Tools: ${jobSite.authorizedTools.length}'),
            Text('Alerts: ${jobSite.alertsEnabled ? 'Enabled' : 'Disabled'}'),
            if (jobSite.exposureLimits != null) 
              Text('Custom Limits: ${jobSite.exposureLimits!.length} configured'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editJobSite(context, jobSite);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails(BuildContext context, ToolProximityAlert alert) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Proximity Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${alert.alertType.replaceAll('_', ' ').toUpperCase()}'),
            Text('Severity: ${alert.severity.toUpperCase()}'),
            Text('Distance: ${alert.distance.toStringAsFixed(1)}m'),
            Text('Time: ${_formatDateTime(alert.triggeredAt)}'),
            if (alert.toolId.isNotEmpty) Text('Tool: ${alert.toolId}'),
            if (alert.workerId.isNotEmpty) Text('Worker: ${alert.workerId}'),
            const SizedBox(height: 8),
            Text('Message:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(alert.message ?? 'No message'),
          ],
        ),
        actions: [
          if (!alert.acknowledged) ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Acknowledge alert through view model
              },
              child: const Text('Acknowledge'),
            ),
          ] else ...[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ],
      ),
    );
  }

  void _showHotSpotDetails(BuildContext context, VibrationHotSpot hotSpot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Vibration Hot Spot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vibration Level: ${hotSpot.vibrationLevel.toStringAsFixed(1)} m/s²'),
            Text('Exposure Time: ${hotSpot.exposureTime.toStringAsFixed(0)} minutes'),
            Text('Sessions: ${hotSpot.sessionCount}'),
            Text('Risk Level: ${hotSpot.riskLevel.name.toUpperCase()}'),
            Text('Severity: ${hotSpot.severity.toUpperCase()}'),
            const SizedBox(height: 8),
            Text('Tools Used:', style: const TextStyle(fontWeight: FontWeight.bold)),
            ...hotSpot.toolsUsed.map((tool) => Text('• $tool')),
            const SizedBox(height: 8),
            Text('Recommendations:', style: const TextStyle(fontWeight: FontWeight.bold)),
            ...hotSpot.recommendations.map((rec) => Text('• $rec')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to detailed analysis
            },
            child: const Text('View Analysis'),
          ),
        ],
      ),
    );
  }

  void _createGeofence(BuildContext context, LocationDashboardViewModel model) {
    Navigator.pushNamed(context, '/create-geofence');
  }

  void _editJobSite(BuildContext context, JobSite jobSite) {
    Navigator.pushNamed(context, '/edit-job-site', arguments: jobSite.id);
  }

  void _exportLocationData(BuildContext context, LocationDashboardViewModel model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Location Data'),
        content: const Text('Select export format:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              model.exportLocationData('csv');
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              model.exportLocationData('json');
            },
            child: const Text('JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showProximitySettings(BuildContext context, LocationDashboardViewModel model) {
    Navigator.pushNamed(context, '/proximity-settings');
  }

  void _generateHeatMapReport(BuildContext context, LocationDashboardViewModel model) {
    model.generateHeatMapReport();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generating heat map report...')),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class LocationDashboardViewModel extends BaseViewModel {
  final ToolLocationService _toolLocationService = ToolLocationService();
  final WorkerLocationService _workerLocationService = WorkerLocationService();
  final GeofencingService _geofencingService = GeofencingService();
  final VibrationHeatMapService _heatMapService = VibrationHeatMapService();
  final ToolProximityService _proximityService = ToolProximityService();

  // Data
  List<ToolLocationData> toolLocations = [];
  List<WorkerLocationData> workerLocations = [];
  List<JobSite> activeJobSites = [];
  List<VibrationHeatMapPoint> heatMapPoints = [];
  List<VibrationHotSpot> hotSpots = [];
  List<ToolProximityAlert> proximityAlerts = [];
  List<GeofenceEvent> recentGeofenceEvents = [];

  // UI State
  MapViewType selectedMapView = MapViewType.tools;

  Future<void> initialize() async {
    setBusy(true);
    
    try {
      await Future.wait([
        _toolLocationService.initialize(),
        _workerLocationService.initialize(),
        _geofencingService.initialize(),
        _heatMapService.initialize(),
        _proximityService.initialize(),
      ]);

      await _loadData();
      _setupRealTimeUpdates();
    } catch (e) {
      print('Error initializing location dashboard: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadToolLocations(),
      _loadWorkerLocations(),
      _loadActiveJobSites(),
      _loadHeatMapData(),
      _loadProximityAlerts(),
      _loadGeofenceEvents(),
    ]);
  }

  Future<void> _loadToolLocations() async {
    toolLocations = await _toolLocationService.getAllActive();
    notifyListeners();
  }

  Future<void> _loadWorkerLocations() async {
    workerLocations = await _workerLocationService.getAllActive();
    notifyListeners();
  }

  Future<void> _loadActiveJobSites() async {
    activeJobSites = _geofencingService.getActiveJobSites();
    notifyListeners();
  }

  Future<void> _loadHeatMapData() async {
    heatMapPoints = await _heatMapService.getCachedHeatMap();
    hotSpots = await _heatMapService.identifyHotSpots();
    notifyListeners();
  }

  Future<void> _loadProximityAlerts() async {
    proximityAlerts = await _proximityService.getProximityAlerts(
      acknowledged: false,
      limit: 50,
    );
    notifyListeners();
  }

  Future<void> _loadGeofenceEvents() async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(const Duration(hours: 24));
    
    recentGeofenceEvents = await _geofencingService.getGeofenceEvents(
      startTime: startTime,
      endTime: endTime,
      limit: 20,
    );
    notifyListeners();
  }

  void _setupRealTimeUpdates() {
    _toolLocationService.locationStream.listen((locations) {
      toolLocations = locations;
      notifyListeners();
    });

    _workerLocationService.locationStream.listen((locations) {
      workerLocations = locations;
      notifyListeners();
    });

    _proximityService.proximityAlertStream.listen((alert) {
      proximityAlerts.insert(0, alert);
      notifyListeners();
    });

    _geofencingService.geofenceEventStream.listen((event) {
      recentGeofenceEvents.insert(0, event);
      if (recentGeofenceEvents.length > 20) {
        recentGeofenceEvents.removeLast();
      }
      notifyListeners();
    });
  }

  void changeMapView(MapViewType viewType) {
    selectedMapView = viewType;
    notifyListeners();
    
    if (viewType == MapViewType.heatmap) {
      _loadHeatMapData();
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await _proximityService.acknowledgeAlert(alertId);
    await _loadProximityAlerts();
  }

  Future<void> exportLocationData(String format) async {
    // Implementation would depend on the format
    print('Exporting location data in $format format');
  }

  Future<void> generateHeatMapReport() async {
    // Generate comprehensive heat map report
    print('Generating heat map report');
  }

  @override
  void dispose() {
    _toolLocationService.dispose();
    _workerLocationService.dispose();
    _geofencingService.dispose();
    _heatMapService.dispose();
    _proximityService.dispose();
    super.dispose();
  }
}

enum MapViewType {
  tools,
  workers,
  heatmap,
}