import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/feedback_service.dart';
import 'feedback_viewmodel.dart';

class FeedbackView extends StatelessWidget {
  const FeedbackView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<FeedbackViewModel>.reactive(
      viewModelBuilder: () => FeedbackViewModel(),
      builder: (context, viewModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Send Feedback'),
            actions: [
              if (viewModel.canSubmitFeedback)
                TextButton(
                  onPressed: viewModel.isFormValid ? viewModel.submitFeedback : null,
                  child: const Text('Send'),
                ),
            ],
          ),
          body: viewModel.isBusy
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rate limiting message
                      if (!viewModel.canSubmitFeedback)
                        Card(
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You can submit feedback once per day. Please try again tomorrow.',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      if (!viewModel.canSubmitFeedback) const SizedBox(height: 16),
                      
                      // Feedback type selection
                      Text(
                        'What type of feedback are you sharing?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...viewModel.feedbackCategories.map((category) => 
                        _buildCategoryCard(context, category, viewModel)),
                      
                      const SizedBox(height: 24),
                      
                      // Rating
                      Text(
                        'How would you rate your experience?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildRatingWidget(context, viewModel),
                      
                      const SizedBox(height: 24),
                      
                      // Message
                      Text(
                        'Tell us more (optional)',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: viewModel.messageController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Describe your feedback in detail...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Screenshot option
                      if (viewModel.selectedType != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add Screenshot (Optional)',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Screenshots help us understand issues better',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: viewModel.takeScreenshot,
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Take Screenshot'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: viewModel.selectImage,
                                        icon: const Icon(Icons.image),
                                        label: const Text('Choose Image'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (viewModel.screenshotPath != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 100,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        viewModel.screenshotPath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => 
                                          const Icon(Icons.image, size: 48),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: viewModel.removeScreenshot,
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: viewModel.canSubmitFeedback && viewModel.isFormValid
                              ? viewModel.submitFeedback
                              : null,
                          child: const Text('Send Feedback'),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    FeedbackCategory category,
    FeedbackViewModel viewModel,
  ) {
    final isSelected = viewModel.selectedType == category.type;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected 
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: () => viewModel.selectFeedbackType(category.type),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                category.icon,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : null,
                      ),
                    ),
                    Text(
                      category.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingWidget(BuildContext context, FeedbackViewModel viewModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final isSelected = rating <= viewModel.rating;
        
        return GestureDetector(
          onTap: () => viewModel.setRating(rating),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              isSelected ? Icons.star : Icons.star_border,
              size: 40,
              color: isSelected 
                  ? Colors.amber
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
          ),
        );
      }),
    );
  }
}

