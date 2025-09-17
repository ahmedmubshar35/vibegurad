import 'package:flutter/material.dart';

class ToolSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final String searchQuery;
  final String hintText;

  const ToolSearchBar({
    super.key,
    required this.onSearchChanged,
    required this.searchQuery,
    this.hintText = 'Search tools by name, brand, model, or category...',
  });

  @override
  State<ToolSearchBar> createState() => _ToolSearchBarState();
}

class _ToolSearchBarState extends State<ToolSearchBar> {
  late TextEditingController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(ToolSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    widget.onSearchChanged(query);
  }

  void _clearSearch() {
    _controller.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Search Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: _isSearching 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _isSearching
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Results Count (optional)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Clear Button
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            tooltip: 'Clear search',
                          ),
                        ],
                      )
                    : Icon(
                        Icons.tune,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          
              ],
      ),
    );
  }

}
