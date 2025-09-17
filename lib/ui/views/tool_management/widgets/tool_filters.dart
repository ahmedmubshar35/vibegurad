import 'package:flutter/material.dart';

class ToolFilters extends StatelessWidget {
  final String selectedCategory;
  final String selectedBrand;
  final double? maxVibration;
  final bool showOnlyAvailable;
  final List<String> availableCategories;
  final List<String> availableBrands;
  final Function(String) onCategoryChanged;
  final Function(String) onBrandChanged;
  final Function(double?) onVibrationChanged;
  final Function(bool) onAvailabilityChanged;

  const ToolFilters({
    super.key,
    required this.selectedCategory,
    required this.selectedBrand,
    required this.maxVibration,
    required this.showOnlyAvailable,
    required this.availableCategories,
    required this.availableBrands,
    required this.onCategoryChanged,
    required this.onBrandChanged,
    required this.onVibrationChanged,
    required this.onAvailabilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Header
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters())
                TextButton(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Clear All',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Category Filter
          _buildFilterSection(
            context,
            'Category',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableCategories.map((category) => 
                  _buildFilterChip(
                    context,
                    category,
                    selectedCategory == category,
                    () => onCategoryChanged(category),
                    icon: _getCategoryIcon(category),
                  )
                ).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Brand Filter
          _buildFilterSection(
            context,
            'Brand',
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: availableBrands.map((brand) => 
                  _buildFilterChip(
                    context,
                    brand,
                    selectedBrand == brand,
                    () => onBrandChanged(brand),
                    icon: Icons.business,
                  )
                ).toList(),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Vibration Level Filter
          _buildFilterSection(
            context,
            'Max Vibration Level',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: maxVibration ?? 15.0,
                        min: 0.0,
                        max: 15.0,
                        divisions: 15,
                        label: maxVibration != null 
                            ? '${maxVibration!.toStringAsFixed(1)} m/s²' 
                            : 'Any level',
                        onChanged: (value) {
                          onVibrationChanged(value == 15.0 ? null : value);
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () => onVibrationChanged(null),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        'Any',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildVibrationLevelChip(context, 'Low Risk', 0.0, 2.5, Colors.green),
                    const SizedBox(width: 8),
                    _buildVibrationLevelChip(context, 'Medium Risk', 2.5, 5.0, Colors.blue),
                    const SizedBox(width: 8),
                    _buildVibrationLevelChip(context, 'High Risk', 5.0, 10.0, Colors.orange),
                    const SizedBox(width: 8),
                    _buildVibrationLevelChip(context, 'Critical', 10.0, 15.0, Colors.red),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Additional Filters
          _buildFilterSection(
            context,
            'Additional Filters',
            Column(
              children: [
                // Availability Filter
                Row(
                  children: [
                    Checkbox(
                      value: showOnlyAvailable,
                      onChanged: (bool? value) => onAvailabilityChanged(value ?? false),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onAvailabilityChanged(!showOnlyAvailable),
                        child: Text(
                          'Show only available tools',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: showOnlyAvailable ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
        backgroundColor: Theme.of(context).colorScheme.surface,
        side: BorderSide(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildVibrationLevelChip(
    BuildContext context,
    String label,
    double minLevel,
    double maxLevel,
    Color color,
  ) {
    final isActive = maxVibration != null && 
        maxVibration! >= minLevel && 
        maxVibration! < maxLevel;
    
    return GestureDetector(
      onTap: () => onVibrationChanged(maxLevel == 15.0 ? null : maxLevel - 0.1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.5),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? Color.fromARGB(255, (color.red * 0.7).round(), (color.green * 0.7).round(), (color.blue * 0.7).round()) : color,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'drill':
      case 'drilling':
        return Icons.settings;
      case 'grinder':
      case 'grinding':
        return Icons.circle;
      case 'hammer':
      case 'hammering':
        return Icons.handyman;
      case 'saw':
      case 'cutting':
        return Icons.content_cut;
      case 'sander':
      case 'sanding':
        return Icons.circle_outlined;
      case 'impact':
        return Icons.construction;
      case 'all':
        return Icons.all_inclusive;
      default:
        return Icons.build;
    }
  }

  bool _hasActiveFilters() {
    return selectedCategory != 'All' ||
           selectedBrand != 'All' ||
           maxVibration != null ||
           showOnlyAvailable;
  }

  void _clearAllFilters() {
    onCategoryChanged('All');
    onBrandChanged('All');
    onVibrationChanged(null);
    onAvailabilityChanged(false);
  }
}
