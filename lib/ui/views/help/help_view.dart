import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../services/features/help_service.dart';
import 'help_viewmodel.dart';

class HelpView extends StatelessWidget {
  const HelpView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HelpViewModel>.reactive(
      viewModelBuilder: () => HelpViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Help & Support'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: viewModel.toggleSearch,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              if (viewModel.isSearchVisible)
                Container(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: viewModel.searchController,
                    onChanged: viewModel.onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search help topics...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: viewModel.searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: viewModel.clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              
              // Content
              Expanded(
                child: viewModel.isSearching
                    ? _buildSearchResults(context, viewModel)
                    : _buildHelpContent(context, viewModel),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHelpContent(BuildContext context, HelpViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick actions
        _buildQuickActions(context, viewModel),
        const SizedBox(height: 24),
        
        // FAQ Categories
        Text(
          'Frequently Asked Questions',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        ...viewModel.helpCategories.map((category) => 
          _buildCategoryCard(context, category, viewModel)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, HelpViewModel viewModel) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Contact Support',
                    Icons.email,
                    () => viewModel.contactSupport(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Video Tutorial',
                    Icons.play_circle,
                    () => viewModel.openVideoTutorial(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'User Guide',
                    Icons.book,
                    () => viewModel.openUserGuide(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    context,
                    'Report Bug',
                    Icons.bug_report,
                    () => viewModel.reportBug(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    HelpCategory category,
    HelpViewModel viewModel,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(category.icon),
        title: Text(
          category.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: category.questions.map((question) => 
          _buildQuestionTile(context, question)).toList(),
      ),
    );
  }

  Widget _buildQuestionTile(BuildContext context, HelpQuestion question) {
    return ExpansionTile(
      title: Text(
        question.question,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            question.answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, HelpViewModel viewModel) {
    if (viewModel.searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Search Results (${viewModel.searchResults.length})',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...viewModel.searchResults.map((question) => 
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              title: Text(question.question),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(question.answer),
                ),
              ],
            ),
          )),
      ],
    );
  }
}
