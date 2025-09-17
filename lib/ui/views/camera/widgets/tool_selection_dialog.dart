import 'package:flutter/material.dart';
import '../../../../models/tool/tool.dart';
import '../../../../enums/tool_type.dart';

class ToolSelectionDialog extends StatefulWidget {
  final List<Tool> availableTools;
  final Function(Tool) onToolSelected;
  final bool Function(Tool) canSelectTool;
  final Map<String, List<Tool>> toolsByCategory;

  const ToolSelectionDialog({
    super.key,
    required this.availableTools,
    required this.onToolSelected,
    required this.canSelectTool,
    required this.toolsByCategory,
  });

  @override
  State<ToolSelectionDialog> createState() => _ToolSelectionDialogState();
}

class _ToolSelectionDialogState extends State<ToolSelectionDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<Tool> _filteredTools = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _filteredTools = widget.availableTools;
    
    // Initialize tab controller with categories
    final categories = widget.toolsByCategory.keys.toList();
    _tabController = TabController(
      length: categories.length + 1, // +1 for "All" tab
      vsync: this,
    );
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredTools = _searchQuery.isEmpty
          ? widget.availableTools
          : widget.availableTools.where((tool) =>
              tool.name.toLowerCase().contains(_searchQuery) ||
              tool.brand.toLowerCase().contains(_searchQuery) ||
              tool.model.toLowerCase().contains(_searchQuery) ||
              tool.category.toLowerCase().contains(_searchQuery)
            ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.toolsByCategory.keys.toList();
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.build,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Tool',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.availableTools.length} tools available',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tools...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withValues(alpha: 0.1),
                ),
              ),
            ),
            
            // Tab bar for categories
            if (_searchQuery.isEmpty && categories.isNotEmpty)
              SizedBox(
                height: 48,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: [
                    const Tab(text: 'All'),
                    ...categories.map((category) => Tab(text: category)),
                  ],
                ),
              ),
            
            // Tool list
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildToolList(_filteredTools)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildToolList(widget.availableTools),
                        ...categories.map((category) => 
                          _buildToolList(widget.toolsByCategory[category] ?? [])
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolList(List<Tool> tools) {
    if (tools.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tools available',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search or check with your administrator',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Debug: Total available tools: ${widget.availableTools.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        final canSelect = widget.canSelectTool(tool);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getToolTypeColor(tool.type),
              child: Icon(
                _getToolTypeIcon(tool.type),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              tool.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: canSelect ? null : Colors.grey,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tool.brand} ${tool.model}'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.vibration,
                          size: 14,
                          color: _getVibrationColor(tool.vibrationLevel),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tool.vibrationLevel.toStringAsFixed(1)} m/s²',
                          style: TextStyle(
                            color: _getVibrationColor(tool.vibrationLevel),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer,
                          size: 14,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tool.dailyExposureLimit}min/day',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            trailing: canSelect
                ? const Icon(Icons.chevron_right)
                : const Icon(Icons.lock, color: Colors.grey),
            enabled: canSelect,
            onTap: canSelect
                ? () {
                    print('🔧 Tool selected: ${tool.name} (${tool.brand} ${tool.model})');
                    print('🔧 Vibration Level: ${tool.vibrationLevel} m/s²');
                    print('🔧 Can select: $canSelect');
                    Navigator.of(context).pop();
                    widget.onToolSelected(tool);
                  }
                : () {
                    print('❌ Cannot select tool: ${tool.name} - canSelect: $canSelect');
                  },
          ),
        );
      },
    );
  }

  Color _getToolTypeColor(ToolType type) {
    switch (type) {
      case ToolType.drill:
        return Colors.orange;
      case ToolType.grinder:
        return Colors.red;
      case ToolType.jackhammer:
        return Colors.deepOrange;
      case ToolType.saw:
        return Colors.purple;
      case ToolType.hammer:
        return Colors.brown;
      case ToolType.sander:
        return Colors.blue;
      case ToolType.nailer:
        return Colors.green;
      case ToolType.compressor:
        return Colors.teal;
      case ToolType.welder:
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getToolTypeIcon(ToolType type) {
    switch (type) {
      case ToolType.drill:
        return Icons.build;
      case ToolType.grinder:
        return Icons.construction;
      case ToolType.jackhammer:
        return Icons.hardware;
      case ToolType.saw:
        return Icons.content_cut;
      case ToolType.hammer:
        return Icons.handyman;
      case ToolType.sander:
        return Icons.brush;
      case ToolType.nailer:
        return Icons.push_pin;
      case ToolType.compressor:
        return Icons.air;
      case ToolType.welder:
        return Icons.local_fire_department;
      default:
        return Icons.build;
    }
  }

  Color _getVibrationColor(double vibrationLevel) {
    if (vibrationLevel < 2.5) return Colors.green;
    if (vibrationLevel < 5.0) return Colors.orange;
    return Colors.red;
  }
}