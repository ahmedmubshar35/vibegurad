import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../../app/app.locator.dart';
import '../../../../services/core/authentication_service.dart';
import '../../../../services/features/tool_service.dart';
import '../../../../services/features/session_service.dart';
import '../../../../models/tool/tool.dart';
import '../../../../models/timer/timer_session.dart';
import '../../../../models/core/user.dart';
import '../../../../app/app.router.dart';
import '../../../../services/core/notification_manager.dart';

class ToolDetailsViewModel extends BaseViewModel {
  final _authService = locator<AuthenticationService>();
  final _toolService = locator<ToolService>();
  final _sessionService = locator<SessionService>();
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();

  Tool? _tool;
  List<TimerSession> _recentSessions = [];
  Map<String, dynamic> _toolStats = {};
  bool _isEditing = false;

  // Form controllers
  final displayNameController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final categoryController = TextEditingController();
  final vibrationController = TextEditingController();
  final exposureLimitController = TextEditingController();
  final descriptionController = TextEditingController();

  Tool? get tool => _tool;
  List<TimerSession> get recentSessions => _recentSessions;
  Map<String, dynamic> get toolStats => _toolStats;
  bool get isEditing => _isEditing;
  User? get currentUser => _authService.currentUser;

  bool get isManager => currentUser?.role.name.toLowerCase() == 'manager' || 
                       currentUser?.role.name.toLowerCase() == 'admin';

  bool get canEdit => isManager;
  bool get canDelete => isManager;
  bool get canStartSession => _tool?.isToolActive == true && !(_tool?.needsMaintenance == true);

  // Stats getters
  int get totalSessions => _toolStats['totalSessions'] ?? 0;
  int get totalUsageMinutes => _toolStats['totalUsageMinutes'] ?? 0;
  double get averageSessionLength => _toolStats['averageSessionLength'] ?? 0.0;
  int get uniqueUsers => _toolStats['uniqueUsers'] ?? 0;
  String get lastUsedBy => _toolStats['lastUsedBy'] ?? 'Never';
  DateTime? get lastUsedAt => _toolStats['lastUsedAt'] as DateTime?;
  double get usageThisWeek => _toolStats['usageThisWeek'] ?? 0.0;
  double get usageThisMonth => _toolStats['usageThisMonth'] ?? 0.0;
  int get maintenanceCount => _toolStats['maintenanceCount'] ?? 0;

  void initialize(String toolId) {
    _loadToolDetails(toolId);
  }

  Future<void> _loadToolDetails(String toolId) async {
    setBusy(true);
    
    try {
      // Load tool details
      _tool = await _toolService.getTool(toolId);
      
      if (_tool != null) {
        _initializeFormControllers();
        
        // Load recent sessions and stats
        await Future.wait([
          _loadRecentSessions(),
          _loadToolStats(),
        ]);
      }
    } catch (e) {
      print('Error loading tool details: $e');
      NotificationManager().showError('Error loading tool details: $e');
    } finally {
      setBusy(false);
    }
  }

  void _initializeFormControllers() {
    if (_tool != null) {
      displayNameController.text = _tool!.name;
      brandController.text = _tool!.brand;
      modelController.text = _tool!.model;
      categoryController.text = _tool!.category;
      vibrationController.text = _tool!.vibrationLevel.toString();
      exposureLimitController.text = _tool!.dailyExposureLimit.toString();
      descriptionController.text = _tool!.specifications?.toString() ?? '';
    }
  }

  Future<void> _loadRecentSessions() async {
    if (_tool?.id != null) {
      // TODO: Implement getToolSessions in SessionService
      _recentSessions = [];
    }
  }

  Future<void> _loadToolStats() async {
    if (_tool?.id == null) return;
    
    try {
      // Calculate stats from recent sessions
      // TODO: Implement getToolSessions in SessionService  
      final allSessions = <TimerSession>[];
      
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final monthAgo = now.subtract(const Duration(days: 30));
      
      _toolStats = {
        'totalSessions': allSessions.length,
        'totalUsageMinutes': allSessions.fold(0, (sum, session) => sum + session.totalMinutes),
        'averageSessionLength': allSessions.isNotEmpty ? 
            allSessions.fold(0, (sum, session) => sum + session.totalMinutes) / allSessions.length : 0.0,
        'uniqueUsers': allSessions.map((s) => s.workerId).toSet().length,
        'lastUsedBy': allSessions.isNotEmpty ? allSessions.first.workerId : 'Never',
        'lastUsedAt': allSessions.isNotEmpty ? allSessions.first.startTime : null,
        'usageThisWeek': allSessions.where((s) => s.startTime.isAfter(weekAgo))
            .fold(0.0, (sum, session) => sum + session.totalMinutes / 60.0),
        'usageThisMonth': allSessions.where((s) => s.startTime.isAfter(monthAgo))
            .fold(0.0, (sum, session) => sum + session.totalMinutes / 60.0),
        'maintenanceCount': 0, // TODO: Get from maintenance records
      };
    } catch (e) {
      print('Error loading tool stats: $e');
    }
  }

  // Editing methods
  void toggleEditing() {
    if (!canEdit) {
      NotificationManager().showWarning('Only managers can edit tool details');
      return;
    }
    
    _isEditing = !_isEditing;
    
    if (!_isEditing) {
      // Reset form to original values if canceling
      _initializeFormControllers();
    }
    
    notifyListeners();
  }

  Future<void> saveChanges() async {
    if (!canEdit || _tool == null) return;
    
    // Validate input
    if (displayNameController.text.trim().isEmpty) {
      NotificationManager().showWarning('Display name is required');
      return;
    }
    
    if (brandController.text.trim().isEmpty) {
      NotificationManager().showWarning('Brand is required');
      return;
    }
    
    setBusy(true);
    
    try {
      final updatedTool = _tool!.copyWith(
        name: displayNameController.text.trim(),
        brand: brandController.text.trim(),
        model: modelController.text.trim(),
        category: categoryController.text.trim(),
        vibrationLevel: double.tryParse(vibrationController.text) ?? _tool!.vibrationLevel,
        dailyExposureLimit: int.tryParse(exposureLimitController.text) ?? 360,
        specifications: descriptionController.text.trim().isEmpty ? null : {'description': descriptionController.text.trim()},
      );
      
      await _toolService.updateTool(_tool!.id!, updatedTool);
      _tool = updatedTool;
      _isEditing = false;
      
      NotificationManager().showSuccess('Tool updated successfully');
    } catch (e) {
      NotificationManager().showError('Error updating tool: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  // Tool management actions
  Future<void> toggleAvailability() async {
    if (!isManager || _tool == null) return;
    
    setBusy(true);
    
    try {
      final newAvailability = !_tool!.isToolActive;
      // TODO: Implement updateToolAvailability in ToolService
      await _toolService.updateTool(_tool!.id!, _tool!.copyWith(isToolActive: newAvailability));
      
      _tool = _tool!.copyWith(isToolActive: newAvailability);
      
      NotificationManager().showSuccess('Tool ${newAvailability ? 'enabled' : 'disabled'} successfully');
    } catch (e) {
      NotificationManager().showError('Error updating availability: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> scheduleMaintenance() async {
    if (!isManager || _tool == null) return;
    
    setBusy(true);
    
    try {
      // TODO: Implement scheduleToolMaintenance in ToolService
      final nextMaintenance = DateTime.now().add(const Duration(days: 30));
      await _toolService.updateTool(_tool!.id!, _tool!.copyWith(nextMaintenanceDate: nextMaintenance));
      
      _tool = _tool!.copyWith(nextMaintenanceDate: nextMaintenance);
      
      NotificationManager().showSuccess('Maintenance scheduled successfully');
    } catch (e) {
      NotificationManager().showError('Error scheduling maintenance: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> completeMaintenance() async {
    if (!isManager || _tool == null) return;
    
    setBusy(true);
    
    try {
      // TODO: Implement completeToolMaintenance in ToolService
      await _toolService.updateTool(_tool!.id!, _tool!.copyWith(
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 30)),
        lastMaintenanceDate: DateTime.now(),
      ));
      
      _tool = _tool!.copyWith(
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 30)), // Reset maintenance date
        isToolActive: true,
        lastMaintenanceDate: DateTime.now(),
      );
      
      NotificationManager().showSuccess('Maintenance completed successfully');
      
      // Refresh stats
      await _loadToolStats();
    } catch (e) {
      NotificationManager().showError('Error completing maintenance: $e');
    } finally {
      setBusy(false);
      notifyListeners();
    }
  }

  Future<void> deleteTool() async {
    if (!canDelete || _tool == null) return;
    
    setBusy(true);
    
    try {
      await _toolService.deleteTool(_tool!.id!);
      
      NotificationManager().showSuccess('Tool deleted successfully');
      
      // Navigate back
      _navigationService.back();
    } catch (e) {
      NotificationManager().showError('Error deleting tool: $e');
    } finally {
      setBusy(false);
    }
  }

  // Session management
  Future<void> startTimerSession() async {
    if (!canStartSession || _tool == null) {
      NotificationManager().showWarning(canStartSession ? 'Tool is not available' : 'Cannot start session with this tool');
      return;
    }
    
    // TODO: Implement timer navigation when route arguments are available
    NotificationManager().showInfo('Timer session navigation coming soon');
  }

  void viewSessionHistory() {
    // TODO: Implement history navigation when route arguments are available
    NotificationManager().showInfo('Session history navigation coming soon');
  }

  void navigateToSessionDetails(TimerSession session) {
    // TODO: Implement session details navigation when route is available
    NotificationManager().showInfo('Session details navigation coming soon');
  }

  // Utility methods
  String getToolStatusText() {
    if (_tool == null) return 'Unknown';
    
    if (!_tool!.isToolActive) return 'Unavailable';
    if (_tool!.needsMaintenance) return 'Maintenance Required';
    if (_tool!.assignedWorkerId != null) return 'Currently Assigned';
    return 'Available';
  }

  Color getToolStatusColor() {
    if (_tool == null) return Colors.grey;
    
    if (!_tool!.isToolActive) return Colors.grey;
    if (_tool!.needsMaintenance) return Colors.orange;
    if (_tool!.assignedWorkerId != null) return Colors.blue;
    return Colors.green;
  }

  String getVibrationRiskLevel() {
    final vibration = _tool?.vibrationLevel;
    if (vibration == null || vibration == 0.0) return 'Unknown';
    
    if (vibration < 2.5) return 'Low Risk';
    if (vibration < 5.0) return 'Medium Risk';
    if (vibration < 10.0) return 'High Risk';
    return 'Critical Risk';
  }

  Color getVibrationRiskColor() {
    final vibration = _tool?.vibrationLevel;
    if (vibration == null || vibration == 0.0) return Colors.grey;
    
    if (vibration < 2.5) return Colors.green;
    if (vibration < 5.0) return Colors.blue;
    if (vibration < 10.0) return Colors.orange;
    return Colors.red;
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }

  String formatLastUsed() {
    if (lastUsedAt == null) return 'Never used';
    
    final now = DateTime.now();
    final difference = now.difference(lastUsedAt!);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> refreshData() async {
    if (_tool?.id != null) {
      await _loadToolDetails(_tool!.id!);
    }
  }

  @override
  void dispose() {
    displayNameController.dispose();
    brandController.dispose();
    modelController.dispose();
    categoryController.dispose();
    vibrationController.dispose();
    exposureLimitController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
