import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/tool.dart';
import '../../models/ai/tool_image_database.dart';
import '../../enums/tool_type.dart';
import 'tool_service.dart';
import '../core/authentication_service.dart';

@lazySingleton
class ToolCatalogService with ListenableServiceMixin {
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();
  final ToolService _toolService = GetIt.instance<ToolService>();
  final AuthenticationService _authService = GetIt.instance<AuthenticationService>();
  
  // Reactive values for catalog state
  final ReactiveValue<List<Tool>> _catalogTools = ReactiveValue<List<Tool>>([]);
  final ReactiveValue<List<Tool>> _filteredTools = ReactiveValue<List<Tool>>([]);
  final ReactiveValue<bool> _isLoading = ReactiveValue<bool>(false);
  final ReactiveValue<String> _currentSearchQuery = ReactiveValue<String>('');
  final ReactiveValue<Map<String, dynamic>> _activeFilters = ReactiveValue<Map<String, dynamic>>({});
  
  List<Tool> get catalogTools => _catalogTools.value;
  List<Tool> get filteredTools => _filteredTools.value;
  bool get isLoading => _isLoading.value;
  String get currentSearchQuery => _currentSearchQuery.value;
  Map<String, dynamic> get activeFilters => _activeFilters.value;
  
  // Search and filter controllers
  Timer? _searchDebounceTimer;
  final StreamController<List<Tool>> _searchResultsController = StreamController<List<Tool>>.broadcast();
  Stream<List<Tool>> get searchResultsStream => _searchResultsController.stream;
  
  // Catalog statistics
  final ReactiveValue<Map<String, dynamic>> _catalogStats = ReactiveValue<Map<String, dynamic>>({});
  Map<String, dynamic> get catalogStats => _catalogStats.value;
  
  ToolCatalogService() {
    listenToReactiveValues([
      _catalogTools, 
      _filteredTools, 
      _isLoading, 
      _currentSearchQuery, 
      _activeFilters,
      _catalogStats
    ]);
    _initializeCatalog();
  }
  
  // Initialize tool catalog
  Future<void> _initializeCatalog() async {
    _isLoading.value = true;
    
    try {
      await loadCatalogTools();
      await _updateCatalogStatistics();
      
      _filteredTools.value = _catalogTools.value;
      
      print('✅ Tool catalog initialized with ${_catalogTools.value.length} tools');
    } catch (e) {
      print('❌ Failed to initialize tool catalog: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to load tool catalog',
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  // Load tools into catalog
  Future<void> loadCatalogTools() async {
    try {
      final currentUser = _authService.currentUser;
      List<Tool> tools = [];
      
      if (currentUser?.companyId != null) {
        // Load company tools
        final companyTools = await _toolService.getCompanyTools(currentUser!.companyId!).first;
        tools.addAll(companyTools);
      }
      
      // Add sample tools from database for demonstration
      tools.addAll(_generateToolsFromDatabase());
      
      // Remove duplicates based on ID
      final uniqueTools = <String, Tool>{};
      for (final tool in tools) {
        final toolId = tool.id ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';
        uniqueTools[toolId] = tool;
      }
      
      _catalogTools.value = uniqueTools.values.toList();
      _filteredTools.value = _catalogTools.value;
      
    } catch (e) {
      throw Exception('Failed to load catalog tools: $e');
    }
  }
  
  // Generate tools from database for catalog
  List<Tool> _generateToolsFromDatabase() {
    final tools = <Tool>[];
    final database = ToolImageDatabase.getAllEntries();
    
    for (final entry in database.entries) {
      final toolType = entry.key;
      final toolEntry = entry.value;
      
      // Generate tools for each brand in the database
      for (final brand in toolEntry.brandColors.keys) {
        for (final model in toolEntry.commonModels.take(2)) { // Limit to 2 models per brand
          tools.add(Tool(
            id: 'catalog_${toolType.toString().split('.').last}_${brand.toLowerCase()}_${model.toLowerCase()}',
            name: '$brand $model',
            brand: brand,
            model: model,
            type: toolType,
            category: toolEntry.keywords.first.toUpperCase(),
            companyId: 'catalog',
            serialNumber: '${brand.substring(0, 3).toUpperCase()}-${model.toUpperCase()}-${DateTime.now().millisecondsSinceEpoch % 1000}',
            vibrationLevel: toolEntry.vibrationLevels['medium'] ?? 5.0,
            frequency: 60.0 + (toolEntry.vibrationLevels['medium'] ?? 5.0) * 10,
            dailyExposureLimit: (480 / (toolEntry.vibrationLevels['medium'] ?? 5.0)).round(),
            weeklyExposureLimit: (480 / (toolEntry.vibrationLevels['medium'] ?? 5.0)).round() * 5,
            specifications: {
              'description': 'Professional ${toolEntry.keywords.first} from $brand. Features: ${toolEntry.visualFeatures.take(3).join(", ")}.',
              'vibration_category': toolEntry.getVibrationCategory(toolEntry.vibrationLevels['medium'] ?? 5.0),
              'keywords': toolEntry.keywords.take(5).toList(),
              'features': toolEntry.visualFeatures.take(3).toList(),
            },
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }
    }
    
    return tools;
  }
  
  // Search tools with query
  Future<void> searchTools(String query, {bool debounce = true}) async {
    _currentSearchQuery.value = query;
    
    if (debounce) {
      // Cancel previous timer
      _searchDebounceTimer?.cancel();
      
      // Set new timer
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performSearch(query);
      });
    } else {
      _performSearch(query);
    }
  }
  
  // Perform the actual search
  void _performSearch(String query) {
    if (query.isEmpty) {
      _filteredTools.value = _catalogTools.value;
      _searchResultsController.add(_filteredTools.value);
      return;
    }
    
    final searchQuery = query.toLowerCase();
    final results = _catalogTools.value.where((tool) {
      // Search in name
      if (tool.name.toLowerCase().contains(searchQuery)) return true;
      
      // Search in brand
      if (tool.brand.toLowerCase().contains(searchQuery)) return true;
      
      // Search in model
      if (tool.model.toLowerCase().contains(searchQuery)) return true;
      
      // Search in category
      if (tool.category.toLowerCase().contains(searchQuery)) return true;
      
      // Search in description from specifications
      final description = tool.specifications?['description'] as String?;
      if (description?.toLowerCase().contains(searchQuery) == true) return true;
      
      // Search in tool type
      if (tool.type.toString().toLowerCase().contains(searchQuery)) return true;
      
      // Search in specifications
      if (tool.specifications != null) {
        final specString = tool.specifications.toString().toLowerCase();
        if (specString.contains(searchQuery)) return true;
      }
      
      // Search using database keywords
      final toolEntry = ToolImageDatabase.getEntry(tool.type);
      if (toolEntry != null) {
        if (toolEntry.keywords.any((keyword) => keyword.toLowerCase().contains(searchQuery))) {
          return true;
        }
      }
      
      return false;
    }).toList();
    
    // Sort results by relevance
    results.sort((a, b) => _calculateRelevanceScore(b, searchQuery).compareTo(_calculateRelevanceScore(a, searchQuery)));
    
    _filteredTools.value = results;
    _searchResultsController.add(results);
  }
  
  // Calculate search relevance score
  double _calculateRelevanceScore(Tool tool, String query) {
    double score = 0.0;
    
    // Exact matches get highest score
    if (tool.name.toLowerCase() == query) score += 10.0;
    if (tool.brand.toLowerCase() == query) score += 8.0;
    if (tool.model.toLowerCase() == query) score += 8.0;
    
    // Starts with matches
    if (tool.name.toLowerCase().startsWith(query)) score += 5.0;
    if (tool.brand.toLowerCase().startsWith(query)) score += 4.0;
    if (tool.model.toLowerCase().startsWith(query)) score += 4.0;
    
    // Contains matches
    if (tool.name.toLowerCase().contains(query)) score += 3.0;
    if (tool.brand.toLowerCase().contains(query)) score += 2.0;
    if (tool.model.toLowerCase().contains(query)) score += 2.0;
    if (tool.category.toLowerCase().contains(query)) score += 1.5;
    
    // Description matches (from specifications)
    final description = tool.specifications?['description'] as String?;
    if (description?.toLowerCase().contains(query) == true) score += 1.0;
    
    return score;
  }
  
  // Apply filters
  void applyFilters(Map<String, dynamic> filters) {
    _activeFilters.value = filters;
    
    List<Tool> results = _catalogTools.value;
    
    // Filter by tool type
    if (filters.containsKey('toolType') && filters['toolType'] != null) {
      final filterType = filters['toolType'] as ToolType;
      results = results.where((tool) => tool.type == filterType).toList();
    }
    
    // Filter by brand
    if (filters.containsKey('brand') && filters['brand'] != null) {
      final filterBrand = filters['brand'] as String;
      results = results.where((tool) => tool.brand.toLowerCase().contains(filterBrand.toLowerCase())).toList();
    }
    
    // Filter by vibration level range
    if (filters.containsKey('vibrationRange') && filters['vibrationRange'] != null) {
      final range = filters['vibrationRange'] as Map<String, double>;
      final minVibration = range['min'] ?? 0.0;
      final maxVibration = range['max'] ?? double.infinity;
      results = results.where((tool) => 
        tool.vibrationLevel >= minVibration && tool.vibrationLevel <= maxVibration).toList();
    }
    
    // Filter by daily exposure limit
    if (filters.containsKey('exposureLimit') && filters['exposureLimit'] != null) {
      final minLimit = filters['exposureLimit'] as int;
      results = results.where((tool) => tool.dailyExposureLimit >= minLimit).toList();
    }
    
    // Filter by availability
    if (filters.containsKey('availableOnly') && filters['availableOnly'] == true) {
      results = results.where((tool) => !tool.needsMaintenance && tool.assignedWorkerId == null).toList();
    }
    
    // Filter by category
    if (filters.containsKey('category') && filters['category'] != null) {
      final filterCategory = filters['category'] as String;
      results = results.where((tool) => tool.category.toLowerCase().contains(filterCategory.toLowerCase())).toList();
    }
    
    _filteredTools.value = results;
    _searchResultsController.add(results);
  }
  
  // Clear all filters
  void clearFilters() {
    _activeFilters.value = {};
    _filteredTools.value = _catalogTools.value;
    _searchResultsController.add(_filteredTools.value);
  }
  
  // Get tools by category
  Map<String, List<Tool>> getToolsByCategory() {
    final categorizedTools = <String, List<Tool>>{};
    
    for (final tool in _filteredTools.value) {
      final category = tool.category.isNotEmpty ? tool.category : 'Other';
      if (!categorizedTools.containsKey(category)) {
        categorizedTools[category] = [];
      }
      categorizedTools[category]!.add(tool);
    }
    
    // Sort tools within each category
    for (final category in categorizedTools.keys) {
      categorizedTools[category]!.sort((a, b) => a.name.compareTo(b.name));
    }
    
    return categorizedTools;
  }
  
  // Get tools by brand
  Map<String, List<Tool>> getToolsByBrand() {
    final brandTools = <String, List<Tool>>{};
    
    for (final tool in _filteredTools.value) {
      if (!brandTools.containsKey(tool.brand)) {
        brandTools[tool.brand] = [];
      }
      brandTools[tool.brand]!.add(tool);
    }
    
    // Sort tools within each brand
    for (final brand in brandTools.keys) {
      brandTools[brand]!.sort((a, b) => a.name.compareTo(b.name));
    }
    
    return brandTools;
  }
  
  // Get available filter options
  Map<String, List<dynamic>> getFilterOptions() {
    final options = <String, List<dynamic>>{
      'toolTypes': ToolType.values,
      'brands': _catalogTools.value.map((tool) => tool.brand).toSet().toList()..sort(),
      'categories': _catalogTools.value.map((tool) => tool.category).where((c) => c.isNotEmpty).toSet().toList()..sort(),
    };
    
    // Vibration level ranges
    final vibrationLevels = _catalogTools.value.map((tool) => tool.vibrationLevel).toList()..sort();
    if (vibrationLevels.isNotEmpty) {
      options['vibrationRange'] = [
        {'label': 'Low (< 2.5 m/s²)', 'min': 0.0, 'max': 2.5},
        {'label': 'Medium (2.5 - 5.0 m/s²)', 'min': 2.5, 'max': 5.0},
        {'label': 'High (> 5.0 m/s²)', 'min': 5.0, 'max': double.infinity},
      ];
    }
    
    return options;
  }
  
  // Update catalog statistics
  Future<void> _updateCatalogStatistics() async {
    final tools = _catalogTools.value;
    
    if (tools.isEmpty) {
      _catalogStats.value = {};
      return;
    }
    
    final stats = <String, dynamic>{
      'totalTools': tools.length,
      'uniqueBrands': tools.map((tool) => tool.brand).toSet().length,
      'toolTypes': tools.map((tool) => tool.type).toSet().length,
      'categories': tools.map((tool) => tool.category).where((c) => c.isNotEmpty).toSet().length,
      'averageVibrationLevel': tools.map((tool) => tool.vibrationLevel).reduce((a, b) => a + b) / tools.length,
      'averageExposureLimit': tools.map((tool) => tool.dailyExposureLimit).reduce((a, b) => a + b) / tools.length,
    };
    
    // Brand distribution
    final brandCounts = <String, int>{};
    for (final tool in tools) {
      brandCounts[tool.brand] = (brandCounts[tool.brand] ?? 0) + 1;
    }
    stats['brandDistribution'] = brandCounts.entries
        .map((e) => {'brand': e.key, 'count': e.value})
        .toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // Tool type distribution
    final typeCounts = <ToolType, int>{};
    for (final tool in tools) {
      typeCounts[tool.type] = (typeCounts[tool.type] ?? 0) + 1;
    }
    stats['typeDistribution'] = typeCounts.entries
        .map((e) => {'type': e.key.toString().split('.').last, 'count': e.value})
        .toList()..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    
    // Vibration level distribution
    int lowVibration = 0, mediumVibration = 0, highVibration = 0;
    for (final tool in tools) {
      if (tool.vibrationLevel <= 2.5) lowVibration++;
      else if (tool.vibrationLevel <= 5.0) mediumVibration++;
      else highVibration++;
    }
    stats['vibrationDistribution'] = {
      'low': lowVibration,
      'medium': mediumVibration,
      'high': highVibration,
    };
    
    _catalogStats.value = stats;
  }
  
  // Get tool details by ID
  Tool? getToolById(String toolId) {
    try {
      return _catalogTools.value.firstWhere((tool) => tool.id == toolId);
    } catch (e) {
      return null;
    }
  }
  
  // Get similar tools
  List<Tool> getSimilarTools(Tool tool, {int limit = 5}) {
    final similarTools = _catalogTools.value.where((t) => 
      t.id != tool.id && (
        t.type == tool.type ||
        t.brand == tool.brand ||
        (t.vibrationLevel - tool.vibrationLevel).abs() < 2.0
      )
    ).toList();
    
    // Sort by similarity score
    similarTools.sort((a, b) => _calculateSimilarityScore(b, tool).compareTo(_calculateSimilarityScore(a, tool)));
    
    return similarTools.take(limit).toList();
  }
  
  // Calculate similarity score between tools
  double _calculateSimilarityScore(Tool tool1, Tool tool2) {
    double score = 0.0;
    
    // Same type gets high score
    if (tool1.type == tool2.type) score += 5.0;
    
    // Same brand gets medium score
    if (tool1.brand == tool2.brand) score += 3.0;
    
    // Similar vibration level
    final vibrationDiff = (tool1.vibrationLevel - tool2.vibrationLevel).abs();
    if (vibrationDiff < 1.0) score += 2.0;
    else if (vibrationDiff < 2.0) score += 1.0;
    
    // Similar category
    if (tool1.category == tool2.category) score += 1.0;
    
    return score;
  }
  
  // Refresh catalog
  Future<void> refreshCatalog() async {
    _isLoading.value = true;
    
    try {
      await loadCatalogTools();
      await _updateCatalogStatistics();
      
      // Reapply current search and filters
      if (_currentSearchQuery.value.isNotEmpty) {
        _performSearch(_currentSearchQuery.value);
      } else if (_activeFilters.value.isNotEmpty) {
        applyFilters(_activeFilters.value);
      } else {
        _filteredTools.value = _catalogTools.value;
      }
      
      _snackbarService.showSnackbar(
        message: 'Catalog refreshed successfully',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to refresh catalog: $e',
      );
    } finally {
      _isLoading.value = false;
    }
  }
  
  // Dispose resources
  Future<void> dispose() async {
    _searchDebounceTimer?.cancel();
    await _searchResultsController.close();
  }
}