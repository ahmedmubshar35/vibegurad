import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../../models/tool/advanced_tool_models.dart';
import '../../../services/features/tool_inventory_service.dart';
import '../../../services/features/tool_checkout_service.dart';
import '../../../services/features/tool_reservation_service.dart';
import '../../../services/features/tool_sharing_service.dart';
import '../../../services/features/tool_condition_service.dart';
import '../../../services/features/tool_performance_service.dart';
import '../../../services/features/tool_warranty_service.dart';
import '../../../services/features/tool_cost_tracking_service.dart';

class AdvancedToolDashboardViewModel extends BaseViewModel {
  final _navigationService = GetIt.instance<NavigationService>();
  final _dialogService = GetIt.instance<DialogService>();
  final _snackbarService = GetIt.instance<SnackbarService>();
  
  final _inventoryService = GetIt.instance<ToolInventoryService>();
  final _checkoutService = GetIt.instance<ToolCheckoutService>();
  final _reservationService = GetIt.instance<ToolReservationService>();
  final _sharingService = GetIt.instance<ToolSharingService>();
  final _conditionService = GetIt.instance<ToolConditionService>();
  final _performanceService = GetIt.instance<ToolPerformanceService>();
  final _warrantyService = GetIt.instance<ToolWarrantyService>();
  final _costService = GetIt.instance<ToolCostTrackingService>();

  // TODO: Get from authentication service
  String? _companyId;
  String? _teamId;
  String? _userId;

  // Data properties
  List<ToolInventory> _inventory = [];
  List<ToolCheckout> _activeCheckouts = [];
  List<ToolCheckout> _overdueCheckouts = [];
  List<ToolReservation> _upcomingReservations = [];
  List<ToolReservation> _pendingReservations = [];
  List<Map<String, dynamic>> _incomingSharingRequests = [];
  List<Map<String, dynamic>> _outgoingSharingRequests = [];
  List<Map<String, dynamic>> _activeSharing = [];
  List<ToolConditionReport> _recentConditionReports = [];
  List<ToolConditionReport> _reportsRequiringAction = [];
  List<ToolPerformanceMetric> _recentPerformanceMetrics = [];
  List<ToolPerformanceMetric> _decliningPerformanceTools = [];
  List<ToolWarranty> _expiringWarranties = [];
  List<ToolWarranty> _activeWarranties = [];
  List<Map<String, dynamic>> _warrantyRenewals = [];
  List<ToolCostRecord> _recentCosts = [];
  Map<String, dynamic> _overviewStats = {};
  Map<String, dynamic> _budgetAnalysis = {};
  List<Map<String, dynamic>> _topCostTools = [];

  // Getters
  List<ToolInventory> get inventory => _inventory;
  List<ToolCheckout> get activeCheckouts => _activeCheckouts;
  List<ToolCheckout> get overdueCheckouts => _overdueCheckouts;
  List<ToolReservation> get upcomingReservations => _upcomingReservations;
  List<ToolReservation> get pendingReservations => _pendingReservations;
  List<Map<String, dynamic>> get incomingSharingRequests => _incomingSharingRequests;
  List<Map<String, dynamic>> get outgoingSharingRequests => _outgoingSharingRequests;
  List<Map<String, dynamic>> get activeSharing => _activeSharing;
  List<ToolConditionReport> get recentConditionReports => _recentConditionReports;
  List<ToolConditionReport> get reportsRequiringAction => _reportsRequiringAction;
  List<ToolPerformanceMetric> get recentPerformanceMetrics => _recentPerformanceMetrics;
  List<ToolPerformanceMetric> get decliningPerformanceTools => _decliningPerformanceTools;
  List<ToolWarranty> get expiringWarranties => _expiringWarranties;
  List<ToolWarranty> get activeWarranties => _activeWarranties;
  List<Map<String, dynamic>> get warrantyRenewals => _warrantyRenewals;
  List<ToolCostRecord> get recentCosts => _recentCosts;
  Map<String, dynamic> get overviewStats => _overviewStats;
  Map<String, dynamic> get budgetAnalysis => _budgetAnalysis;
  List<Map<String, dynamic>> get topCostTools => _topCostTools;

  Future<void> initialize() async {
    await loadData();
  }

  Future<void> loadData() async {
    setBusy(true);
    
    try {
      // Load all data streams
      await Future.wait([
        _loadInventoryData(),
        _loadCheckoutData(),
        _loadReservationData(),
        _loadSharingData(),
        _loadConditionData(),
        _loadPerformanceData(),
        _loadWarrantyData(),
        _loadCostData(),
        _loadOverviewStats(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
      _snackbarService.showSnackbar(
        message: 'Error loading dashboard data: ${e.toString()}',
      );
    } finally {
      setBusy(false);
    }
  }

  Future<void> _loadInventoryData() async {
    if (_companyId == null) return;
    
    try {
      final inventoryStream = _inventoryService.getCompanyInventory(_companyId!);
      inventoryStream.listen((inventory) {
        _inventory = inventory;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading inventory data: $e');
    }
  }

  Future<void> _loadCheckoutData() async {
    if (_companyId == null) return;
    
    try {
      final activeStream = _checkoutService.getActiveCheckouts(_companyId!);
      activeStream.listen((checkouts) {
        _activeCheckouts = checkouts;
        notifyListeners();
      });

      final overdueStream = _checkoutService.getOverdueCheckouts(_companyId!);
      overdueStream.listen((checkouts) {
        _overdueCheckouts = checkouts;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading checkout data: $e');
    }
  }

  Future<void> _loadReservationData() async {
    if (_companyId == null) return;
    
    try {
      final upcomingStream = _reservationService.getUpcomingReservations(_companyId!);
      upcomingStream.listen((reservations) {
        _upcomingReservations = reservations;
        notifyListeners();
      });

      final pendingStream = _reservationService.getPendingReservations(_companyId!);
      pendingStream.listen((reservations) {
        _pendingReservations = reservations;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading reservation data: $e');
    }
  }

  Future<void> _loadSharingData() async {
    if (_teamId == null) return;
    
    try {
      final incomingStream = _sharingService.getIncomingRequests(_teamId!);
      incomingStream.listen((requests) {
        _incomingSharingRequests = requests;
        notifyListeners();
      });

      final outgoingStream = _sharingService.getOutgoingRequests(_teamId!);
      outgoingStream.listen((requests) {
        _outgoingSharingRequests = requests;
        notifyListeners();
      });

      final activeStream = _sharingService.getActiveSharingAgreements(_teamId!);
      activeStream.listen((agreements) {
        _activeSharing = agreements;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading sharing data: $e');
    }
  }

  Future<void> _loadConditionData() async {
    if (_companyId == null) return;
    
    try {
      final recentStream = _conditionService.getCompanyReports(_companyId!);
      recentStream.listen((reports) {
        _recentConditionReports = reports.take(10).toList();
        notifyListeners();
      });

      final actionRequiredStream = _conditionService.getReportsRequiringAction(_companyId!);
      actionRequiredStream.listen((reports) {
        _reportsRequiringAction = reports;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading condition data: $e');
    }
  }

  Future<void> _loadPerformanceData() async {
    if (_companyId == null) return;
    
    try {
      final recentStream = _performanceService.getRecentMetrics(_companyId!);
      recentStream.listen((metrics) {
        _recentPerformanceMetrics = metrics.take(10).toList();
        notifyListeners();
      });

      final decliningStream = _performanceService.getDecliningPerformanceAlerts(_companyId!);
      decliningStream.listen((metrics) {
        _decliningPerformanceTools = metrics;
        notifyListeners();
      });
    } catch (e) {
      print('Error loading performance data: $e');
    }
  }

  Future<void> _loadWarrantyData() async {
    if (_companyId == null) return;
    
    try {
      final expiringStream = _warrantyService.getExpiringWarranties(_companyId!);
      expiringStream.listen((warranties) {
        _expiringWarranties = warranties;
        notifyListeners();
      });

      final allWarrantiesStream = _warrantyService.getCompanyWarranties(_companyId!);
      allWarrantiesStream.listen((warranties) {
        _activeWarranties = warranties.where((w) => w.isActive).take(10).toList();
        notifyListeners();
      });

      // Load renewal recommendations
      final renewals = await _warrantyService.getWarrantyRenewalRecommendations(_companyId!);
      _warrantyRenewals = renewals;
      notifyListeners();
    } catch (e) {
      print('Error loading warranty data: $e');
    }
  }

  Future<void> _loadCostData() async {
    if (_companyId == null) return;
    
    try {
      final recentStream = _costService.getCompanyCostRecords(_companyId!);
      recentStream.listen((costs) {
        _recentCosts = costs.take(10).toList();
        notifyListeners();
      });

      // Load budget analysis
      final budget = await _costService.getBudgetAnalysis(_companyId!, annualBudget: 50000);
      _budgetAnalysis = budget;

      // Load cost analytics
      final analytics = await _costService.getCompanyCostAnalytics(_companyId!);
      if (analytics['hasData'] == true) {
        _topCostTools = (analytics['topCostTools'] as Map<String, double>)
            .entries
            .map((e) => {'toolId': e.key, 'cost': e.value})
            .toList();
      }
      
      notifyListeners();
    } catch (e) {
      print('Error loading cost data: $e');
    }
  }

  Future<void> _loadOverviewStats() async {
    if (_companyId == null) return;
    
    try {
      final inventoryStats = await _inventoryService.getInventoryStats(_companyId!);
      final checkoutStats = await _checkoutService.getCheckoutStats(_companyId!);
      final reservationStats = await _reservationService.getReservationStats(_companyId!);
      final conditionStats = await _conditionService.getConditionStats(_companyId!);
      final performanceStats = await _performanceService.getPerformanceStats(_companyId!);
      final warrantyStats = await _warrantyService.getWarrantyStats(_companyId!);

      _overviewStats = {
        'inventory': inventoryStats,
        'checkouts': checkoutStats,
        'reservations': reservationStats,
        'conditions': conditionStats,
        'performance': performanceStats,
        'warranties': warrantyStats,
      };
      
      notifyListeners();
    } catch (e) {
      print('Error loading overview stats: $e');
    }
  }

  Future<void> refreshData() async {
    await loadData();
    _snackbarService.showSnackbar(message: 'Data refreshed successfully');
  }

  // Handle menu actions
  void handleMenuAction(String action) {
    switch (action) {
      case 'export_data':
        _showExportDataDialog();
        break;
      case 'settings':
        _navigateToSettings();
        break;
      case 'reports':
        _showReportsMenu();
        break;
    }
  }

  // Handle stats tap
  void handleStatsTap(String statType) {
    switch (statType) {
      case 'inventory':
        _showInventoryDetails();
        break;
      case 'checkouts':
        _showCheckoutDetails();
        break;
      case 'reservations':
        _showReservationDetails();
        break;
      case 'conditions':
        _showConditionDetails();
        break;
      case 'performance':
        _showPerformanceDetails();
        break;
      case 'warranties':
        _showWarrantyDetails();
        break;
    }
  }

  // Inventory actions
  void handleInventoryItemTap(ToolInventory item) {
    _navigateToToolDetails(item.toolId);
  }

  void showAddInventoryDialog() {
    _showDialog('Add Inventory Item', 'Feature coming soon');
  }

  void showEditInventoryDialog(ToolInventory item) {
    _showDialog('Edit Inventory', 'Feature coming soon for ${item.toolName}');
  }

  // Checkout actions
  void showCheckoutDialog() {
    _showDialog('Tool Checkout', 'Feature coming soon');
  }

  void showCheckinDialog(ToolCheckout checkout) {
    _showDialog('Tool Check-in', 'Feature coming soon for checkout ${checkout.checkoutId}');
  }

  void showExtendCheckoutDialog(ToolCheckout checkout) {
    _showDialog('Extend Checkout', 'Feature coming soon for checkout ${checkout.checkoutId}');
  }

  // Reservation actions
  void showCreateReservationDialog() {
    _showDialog('Create Reservation', 'Feature coming soon');
  }

  Future<void> approveReservation(ToolReservation reservation) async {
    if (_userId == null) {
      _snackbarService.showSnackbar(message: 'User not authenticated');
      return;
    }
    
    final success = await _reservationService.approveReservation(
      reservationId: reservation.reservationId,
      approvedBy: _userId!,
      approvedByName: 'Current User', // TODO: Get from auth service
    );
    
    if (success) {
      _snackbarService.showSnackbar(message: 'Reservation approved successfully');
    }
  }

  void showRejectReservationDialog(ToolReservation reservation) {
    _showDialog('Reject Reservation', 'Feature coming soon for reservation ${reservation.reservationId}');
  }

  // Sharing actions
  void showRequestSharingDialog() {
    _showDialog('Request Tool Sharing', 'Feature coming soon');
  }

  Future<void> approveSharingRequest(Map<String, dynamic> request) async {
    if (_userId == null) {
      _snackbarService.showSnackbar(message: 'User not authenticated');
      return;
    }
    
    final success = await _sharingService.approveSharingRequest(
      requestId: request['id'],
      approvedByUserId: _userId!,
      approvedByUserName: 'Current User', // TODO: Get from auth service
    );
    
    if (success) {
      _snackbarService.showSnackbar(message: 'Sharing request approved');
    }
  }

  void showRejectSharingDialog(Map<String, dynamic> request) {
    _showDialog('Reject Sharing Request', 'Feature coming soon for request ${request['requestId']}');
  }

  // Condition actions
  void showCreateConditionReportDialog() {
    _showDialog('Create Condition Report', 'Feature coming soon');
  }

  void viewConditionReport(ToolConditionReport report) {
    _showDialog('Condition Report', 'Report ID: ${report.reportId}\nCondition: ${report.condition.name}');
  }

  void showTakeActionDialog(ToolConditionReport report) {
    _showDialog('Take Action', 'Feature coming soon for report ${report.reportId}');
  }

  // Performance actions
  void showRecordMetricDialog() {
    _showDialog('Record Performance Metric', 'Feature coming soon');
  }

  void viewPerformanceTrends(ToolPerformanceMetric metric) {
    _showDialog('Performance Trends', 'Trends for tool ${metric.toolId}');
  }

  void generatePerformanceAlert(ToolPerformanceMetric metric) {
    _showDialog('Performance Alert', 'Alert generated for tool ${metric.toolId}');
  }

  // Warranty actions
  void showCreateWarrantyDialog() {
    _showDialog('Create Warranty', 'Feature coming soon');
  }

  void showExtendWarrantyDialog(ToolWarranty warranty) {
    _showDialog('Extend Warranty', 'Feature coming soon for warranty ${warranty.warrantyId}');
  }

  void showCreateClaimDialog(ToolWarranty warranty) {
    _showDialog('Create Claim', 'Feature coming soon for warranty ${warranty.warrantyId}');
  }

  // Cost actions
  void showRecordCostDialog() {
    _showDialog('Record Cost', 'Feature coming soon');
  }

  void viewCostAnalytics() {
    _showDialog('Cost Analytics', 'Analytics feature coming soon');
  }

  void generateCostReport() {
    _showDialog('Cost Report', 'Report generation feature coming soon');
  }

  // Quick action menu
  void showQuickActionMenu() {
    _showDialog('Quick Actions', 'Quick action menu feature coming soon');
  }

  // Helper methods
  void _showDialog(String title, String message) {
    _dialogService.showDialog(
      title: title,
      description: message,
    );
  }

  void _navigateToToolDetails(String toolId) {
    // Navigate to tool details view
    _snackbarService.showSnackbar(message: 'Navigating to tool details: $toolId');
  }

  void _showExportDataDialog() {
    _showDialog('Export Data', 'Data export feature coming soon');
  }

  void _navigateToSettings() {
    _showDialog('Settings', 'Settings feature coming soon');
  }

  void _showReportsMenu() {
    _showDialog('Reports', 'Reports feature coming soon');
  }

  void _showInventoryDetails() {
    _showDialog('Inventory Details', 'Detailed inventory view coming soon');
  }

  void _showCheckoutDetails() {
    _showDialog('Checkout Details', 'Detailed checkout view coming soon');
  }

  void _showReservationDetails() {
    _showDialog('Reservation Details', 'Detailed reservation view coming soon');
  }

  void _showConditionDetails() {
    _showDialog('Condition Details', 'Detailed condition view coming soon');
  }

  void _showPerformanceDetails() {
    _showDialog('Performance Details', 'Detailed performance view coming soon');
  }

  void _showWarrantyDetails() {
    _showDialog('Warranty Details', 'Detailed warranty view coming soon');
  }
}