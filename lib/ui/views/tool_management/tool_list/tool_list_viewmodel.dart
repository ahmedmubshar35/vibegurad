import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../../app/app.locator.dart';
import '../../../../services/core/authentication_service.dart';
import '../../../../services/features/tool_service.dart';
import '../../../../models/tool/tool.dart';
import '../../../../models/core/user.dart';
import '../../../../services/core/notification_manager.dart';

class ToolListViewModel extends ReactiveViewModel {
  final _authService = locator<AuthenticationService>();
  final _toolService = locator<ToolService>();
  final _navigationService = locator<NavigationService>();
  final _snackbarService = locator<SnackbarService>();

  @override
  List<ListenableServiceMixin> get listenableServices => [];

  List<Tool> _allTools = [];
  List<Tool> _filteredTools = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedBrand = 'All';
  double? _maxVibration;
  bool _showOnlyAvailable = false;
  String _sortBy = 'name'; // name, vibration, category, brand
  bool _sortAscending = true;

  List<Tool> get tools => _filteredTools;
  List<Tool> get allTools => _allTools;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get selectedBrand => _selectedBrand;
  double? get maxVibration => _maxVibration;
  bool get showOnlyAvailable => _showOnlyAvailable;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  User? get currentUser => _authService.currentUser;

  bool get isManager => currentUser?.role.name.toLowerCase() == 'manager' || 
                       currentUser?.role.name.toLowerCase() == 'admin';

  List<String> get availableCategories {
    final categories = _allTools.map((t) => t.category).toSet().toList();
    categories.sort();
    return ['All', ...categories];
  }

  List<String> get availableBrands {
    final brands = _allTools.map((t) => t.brand).toSet().toList();
    brands.sort();
    return ['All', ...brands];
  }

  Map<String, int> get toolCounts {
    return {
      'total': _allTools.length,
      'available': _allTools.where((t) => t.isToolActive).length,
      'highVibration': _allTools.where((t) => t.vibrationLevel > 5.0).length,
      'needsMaintenance': _allTools.where((t) => t.needsMaintenance).length,
    };
  }

  void onModelReady() {
    _loadTools();
  }

  Future<void> _loadTools() async {
    setBusy(true);
    
    try {
      if (currentUser?.companyId != null) {
        print('🔍 Loading tools for company: ${currentUser!.companyId}');
        final toolsStream = _toolService.getCompanyTools(currentUser!.companyId!);
        _allTools = await toolsStream.first;
        print('📋 Loaded ${_allTools.length} tools from database');
        for (final tool in _allTools) {
          print('🔧 Tool: ${tool.displayName} (${tool.brand} ${tool.model})');
        }
        _applyFilters();
        print('🔍 After filtering: ${_filteredTools.length} tools');
      } else {
        print('❌ No company ID found for user: ${currentUser?.email}');
      }
    } catch (e) {
      print('❌ Error loading tools: $e');
      NotificationManager().showError('Error loading tools: $e');
    } finally {
      setBusy(false);
    }
  }

  void _applyFilters() {
    _filteredTools = _allTools.where((tool) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!tool.displayName.toLowerCase().contains(query) &&
            !tool.brand.toLowerCase().contains(query) &&
            !tool.model.toLowerCase().contains(query) &&
            !tool.category.toLowerCase().contains(query)) {
          return false;
        }
      }
      
      // Category filter
      if (_selectedCategory != 'All' && tool.category != _selectedCategory) {
        return false;
      }
      
      // Brand filter
      if (_selectedBrand != 'All' && tool.brand != _selectedBrand) {
        return false;
      }
      
      // Vibration filter
      if (_maxVibration != null && tool.vibrationLevel > _maxVibration!) {
        return false;
      }
      
      // Availability filter
      if (_showOnlyAvailable && !tool.isToolActive) {
        return false;
      }
      
      return true;
    }).toList();
    
    _applySorting();
  }

  void _applySorting() {
    _filteredTools.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
        case 'vibration':
          comparison = a.vibrationLevel.compareTo(b.vibrationLevel);
          break;
        case 'category':
          comparison = a.category.compareTo(b.category);
          break;
        case 'brand':
          comparison = a.brand.compareTo(b.brand);
          break;
        case 'lastUsed':
          comparison = (b.lastMaintenanceDate ?? DateTime(1970)).compareTo(a.lastMaintenanceDate ?? DateTime(1970));
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    notifyListeners();
  }

  // Search and filter methods
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void selectBrand(String brand) {
    _selectedBrand = brand;
    _applyFilters();
  }

  void updateVibrationFilter(double? maxVibration) {
    _maxVibration = maxVibration;
    _applyFilters();
  }

  void toggleAvailabilityFilter() {
    _showOnlyAvailable = !_showOnlyAvailable;
    _applyFilters();
  }

  void updateSorting(String sortBy) {
    if (_sortBy == sortBy) {
      _sortAscending = !_sortAscending;
    } else {
      _sortBy = sortBy;
      _sortAscending = true;
    }
    _applySorting();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _selectedBrand = 'All';
    _maxVibration = null;
    _showOnlyAvailable = false;
    _applyFilters();
  }

  // Navigation methods
  void navigateToToolDetails(Tool tool) {
    // TODO: Implement tool details navigation when route is added
    NotificationManager().showInfo('Tool details navigation coming soon');
  }

  void navigateToAddTool() {
    if (!isManager) {
      NotificationManager().showWarning('Only managers can add new tools');
      return;
    }
    
    // TODO: Implement add tool navigation when route is added
    NotificationManager().showInfo('Add tool navigation coming soon');
  }

  // Tool management methods
  Future<void> toggleToolAvailability(Tool tool) async {
    if (!isManager) {
      NotificationManager().showWarning('Only managers can modify tool availability');
      return;
    }
    
    setBusy(true);
    
    try {
      // TODO: Implement updateToolAvailability in ToolService
      await _toolService.updateTool(tool.id!, tool.copyWith(isToolActive: !tool.isToolActive));
      NotificationManager().showSuccess('${tool.name} ${tool.isToolActive ? 'disabled' : 'enabled'}');
    } catch (e) {
      NotificationManager().showError('Error updating tool: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> markForMaintenance(Tool tool) async {
    if (!isManager) {
      NotificationManager().showWarning('Only managers can schedule maintenance');
      return;
    }
    
    setBusy(true);
    
    try {
      // TODO: Implement scheduleToolMaintenance in ToolService
      final nextMaintenance = DateTime.now().add(const Duration(days: 30));
      await _toolService.updateTool(tool.id!, tool.copyWith(nextMaintenanceDate: nextMaintenance));
      NotificationManager().showSuccess('${tool.name} scheduled for maintenance');
    } catch (e) {
      NotificationManager().showError('Error scheduling maintenance: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> deleteTool(Tool tool) async {
    if (!isManager) {
      NotificationManager().showWarning('Only managers can delete tools');
      return;
    }
    
    setBusy(true);
    
    try {
      await _toolService.deleteTool(tool.id!);
      NotificationManager().showSuccess('${tool.name} deleted successfully');
    } catch (e) {
      NotificationManager().showError('Error deleting tool: $e');
    } finally {
      setBusy(false);
    }
  }

  // Utility methods
  String getToolStatusText(Tool tool) {
    if (!tool.isToolActive) return 'Unavailable';
    if (tool.needsMaintenance) return 'Maintenance Required';
    if (tool.assignedWorkerId != null) return 'Assigned';
    return 'Available';
  }

  Color getToolStatusColor(Tool tool) {
    if (!tool.isToolActive) return Colors.grey;
    if (tool.needsMaintenance) return Colors.orange;
    if (tool.assignedWorkerId != null) return Colors.blue;
    return Colors.green;
  }

  String getVibrationRiskLevel(double vibration) {
    if (vibration == 0.0) return 'Unknown';
    if (vibration < 2.5) return 'Low Risk';
    if (vibration < 5.0) return 'Medium Risk';
    if (vibration < 10.0) return 'High Risk';
    return 'Critical Risk';
  }

  Color getVibrationRiskColor(double vibration) {
    if (vibration == 0.0) return Colors.grey;
    if (vibration < 2.5) return Colors.green;
    if (vibration < 5.0) return Colors.blue;
    if (vibration < 10.0) return Colors.orange;
    return Colors.red;
  }

  Future<void> refreshTools() async {
    await _loadTools();
  }

  // Bulk operations for managers
  Future<void> bulkUpdateAvailability(List<Tool> tools, bool isAvailable) async {
    if (!isManager) return;
    
    setBusy(true);
    
    try {
      await Future.wait(
        tools.map((tool) => _toolService.updateTool(tool.id!, tool.copyWith(isToolActive: isAvailable)))
      );
      
      NotificationManager().showSuccess('${tools.length} tools updated successfully');
    } catch (e) {
      NotificationManager().showError('Error updating tools: $e');
    } finally {
      setBusy(false);
    }
  }

  Future<void> exportToolList() async {
    // TODO: Implement tool list export functionality
    NotificationManager().showInfo('Export functionality coming soon');
  }

}
