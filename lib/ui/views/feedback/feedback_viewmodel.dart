import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/feedback_service.dart';

class FeedbackViewModel extends BaseViewModel {
  final _feedbackService = locator<FeedbackService>();
  final _snackbarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();
  final _imagePicker = ImagePicker();
  
  final TextEditingController _messageController = TextEditingController();
  FeedbackType? _selectedType;
  int _rating = 0;
  String? _screenshotPath;
  
  TextEditingController get messageController => _messageController;
  FeedbackType? get selectedType => _selectedType;
  int get rating => _rating;
  String? get screenshotPath => _screenshotPath;
  
  List<FeedbackCategory> get feedbackCategories => _feedbackService.feedbackCategories;
  bool get canSubmitFeedback => _feedbackService.canSubmitFeedback();
  bool get isFormValid => _selectedType != null && _rating > 0;
  
  void selectFeedbackType(FeedbackType type) {
    _selectedType = type;
    notifyListeners();
  }
  
  void setRating(int rating) {
    _rating = rating;
    notifyListeners();
  }
  
  Future<void> takeScreenshot() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        _screenshotPath = image.path;
        notifyListeners();
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to take screenshot: $e',
      );
    }
  }
  
  Future<void> selectImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        _screenshotPath = image.path;
        notifyListeners();
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Failed to select image: $e',
      );
    }
  }
  
  void removeScreenshot() {
    _screenshotPath = null;
    notifyListeners();
  }
  
  Future<void> submitFeedback() async {
    if (!canSubmitFeedback || !isFormValid) return;
    
    setBusy(true);
    try {
      final success = await _feedbackService.submitFeedback(
        type: _selectedType!,
        message: _messageController.text.trim(),
        rating: _rating,
        screenshotPath: _screenshotPath,
        metadata: {
          'userAgent': 'VibeGuard Mobile App',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      if (success) {
        _snackbarService.showSnackbar(
          message: 'Thank you for your feedback! We\'ll review it soon.',
        );
        _navigationService.back();
      } else {
        _snackbarService.showSnackbar(
          message: 'Failed to submit feedback. Please try again.',
        );
      }
    } catch (e) {
      _snackbarService.showSnackbar(
        message: 'Error submitting feedback: $e',
      );
    } finally {
      setBusy(false);
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

