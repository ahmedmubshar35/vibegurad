import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/help_service.dart';

class HelpViewModel extends BaseViewModel {
  final _helpService = locator<HelpService>();
  final _dialogService = locator<DialogService>();
  
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  bool _isSearching = false;
  List<HelpQuestion> _searchResults = [];
  
  TextEditingController get searchController => _searchController;
  bool get isSearchVisible => _isSearchVisible;
  bool get isSearching => _isSearching;
  List<HelpQuestion> get searchResults => _searchResults;
  List<HelpCategory> get helpCategories => _helpService.helpCategories;
  ContactInfo get contactInfo => _helpService.contactInfo;
  
  void toggleSearch() {
    _isSearchVisible = !_isSearchVisible;
    if (!_isSearchVisible) {
      clearSearch();
    }
    notifyListeners();
  }
  
  void onSearchChanged(String query) {
    if (query.isEmpty) {
      _isSearching = false;
      _searchResults.clear();
    } else {
      _isSearching = true;
      _searchResults = _helpService.searchQuestions(query);
    }
    notifyListeners();
  }
  
  void clearSearch() {
    _searchController.clear();
    _isSearching = false;
    _searchResults.clear();
    notifyListeners();
  }
  
  Future<void> contactSupport() async {
    _dialogService.showDialog(
      title: 'Contact Support',
      description: 'Email: ${contactInfo.email}\nPhone: ${contactInfo.phone}\nWebsite: ${contactInfo.website}',
    );
  }
  
  Future<void> openVideoTutorial() async {
    // In a real app, this would open a video tutorial
    _dialogService.showDialog(
      title: 'Video Tutorial',
      description: 'Video tutorial feature coming soon! For now, please use the FAQ section or contact support.',
    );
  }
  
  Future<void> openUserGuide() async {
    // In a real app, this would open a PDF or web-based user guide
    _dialogService.showDialog(
      title: 'User Guide',
      description: 'User guide feature coming soon! For now, please use the FAQ section or contact support.',
    );
  }
  
  Future<void> reportBug() async {
    _dialogService.showDialog(
      title: 'Report a Bug',
      description: 'Please email us at ${contactInfo.email} with subject "Bug Report - VibeGuard App"',
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
