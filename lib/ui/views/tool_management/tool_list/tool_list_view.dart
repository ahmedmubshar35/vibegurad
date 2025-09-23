import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

import 'tool_list_viewmodel.dart';
import '../widgets/tool_search_bar.dart';
import '../widgets/tool_filters.dart';
import '../widgets/tool_card.dart';

class ToolListView extends StackedView<ToolListViewModel> {
  const ToolListView({super.key});

  @override
  Widget builder(BuildContext context, ToolListViewModel viewModel, Widget? child) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            // App Logo
            const Icon(
              Icons.construction,
              size: 28,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text('Tool Management'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (viewModel.isManager) ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: viewModel.exportToolList,
              tooltip: 'Export Tools',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: viewModel.navigateToAddTool,
              tooltip: 'Add Tool',
            ),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  viewModel.refreshTools();
                  break;
                case 'clear_filters':
                  viewModel.clearFilters();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_filters',
                child: Row(
                  children: [
                    Icon(Icons.clear),
                    SizedBox(width: 8),
                    Text('Clear Filters'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filters
                Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: Column(
                    children: [
                      // Search Bar
                      ToolSearchBar(
                        onSearchChanged: viewModel.updateSearchQuery,
                        searchQuery: viewModel.searchQuery,
                      ),
                      
                      // Filters
                      ToolFilters(
                        selectedCategory: viewModel.selectedCategory,
                        selectedBrand: viewModel.selectedBrand,
                        maxVibration: viewModel.maxVibration,
                        showOnlyAvailable: viewModel.showOnlyAvailable,
                        availableCategories: viewModel.availableCategories,
                        availableBrands: viewModel.availableBrands,
                        onCategoryChanged: viewModel.selectCategory,
                        onBrandChanged: viewModel.selectBrand,
                        onVibrationChanged: viewModel.updateVibrationFilter,
                        onAvailabilityChanged: (_) => viewModel.toggleAvailabilityFilter(),
                      ),
                      
                      // Tool Count Summary
                      _buildToolSummary(context, viewModel),
                    ],
                  ),
                ),
                
                // Sort Options
                _buildSortOptions(context, viewModel),
                
                // Tools List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: viewModel.refreshTools,
                    child: _buildToolsList(context, viewModel),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildToolSummary(BuildContext context, ToolListViewModel viewModel) {
    final counts = viewModel.toolCounts;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              context,
              'Total',
              '${counts['total']}',
              Colors.blue,
              Icons.build,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              context,
              'Available',
              '${counts['available']}',
              Colors.green,
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              context,
              'High Risk',
              '${counts['highVibration']}',
              Colors.red,
              Icons.warning,
            ),
          ),
          Expanded(
            child: _buildSummaryItem(
              context,
              'Maintenance',
              '${counts['needsMaintenance']}',
              Colors.orange,
              Icons.build_circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSortOptions(BuildContext context, ToolListViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Sort by:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip(
                    context,
                    viewModel,
                    'Name',
                    'name',
                  ),
                  _buildSortChip(
                    context,
                    viewModel,
                    'Vibration',
                    'vibration',
                  ),
                  _buildSortChip(
                    context,
                    viewModel,
                    'Category',
                    'category',
                  ),
                  _buildSortChip(
                    context,
                    viewModel,
                    'Brand',
                    'brand',
                  ),
                  _buildSortChip(
                    context,
                    viewModel,
                    'Last Used',
                    'lastUsed',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(
    BuildContext context,
    ToolListViewModel viewModel,
    String label,
    String sortKey,
  ) {
    final isSelected = viewModel.sortBy == sortKey;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                viewModel.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 16,
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (_) => viewModel.updateSorting(sortKey),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _buildToolsList(BuildContext context, ToolListViewModel viewModel) {
    if (viewModel.tools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              viewModel.searchQuery.isNotEmpty || 
              viewModel.selectedCategory != 'All' ||
              viewModel.selectedBrand != 'All' ||
              viewModel.maxVibration != null ||
              viewModel.showOnlyAvailable
                  ? 'No tools match your filters'
                  : 'No tools found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (viewModel.searchQuery.isNotEmpty || 
                viewModel.selectedCategory != 'All' ||
                viewModel.selectedBrand != 'All' ||
                viewModel.maxVibration != null ||
                viewModel.showOnlyAvailable)
              TextButton(
                onPressed: viewModel.clearFilters,
                child: const Text('Clear Filters'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.tools.length,
      itemBuilder: (context, index) {
        final tool = viewModel.tools[index];
        
        return ToolCard(
          tool: tool,
          onTap: () => viewModel.navigateToToolDetails(tool),
          onToggleAvailability: viewModel.isManager ? 
              () => viewModel.toggleToolAvailability(tool) : null,
          onScheduleMaintenance: viewModel.isManager ? 
              () => viewModel.markForMaintenance(tool) : null,
          onDelete: viewModel.isManager ? 
              () => _showDeleteConfirmation(context, viewModel, tool) : null,
          showActions: viewModel.isManager,
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    ToolListViewModel viewModel,
    dynamic tool,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tool'),
        content: Text(
          'Are you sure you want to delete "${tool.displayName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await viewModel.deleteTool(tool);
    }
  }

  @override
  ToolListViewModel viewModelBuilder(BuildContext context) => ToolListViewModel();
}
