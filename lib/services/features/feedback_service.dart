import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@lazySingleton
class FeedbackService with ListenableServiceMixin {
  static const String _feedbackCollection = 'feedback';
  static const String _lastFeedbackDateKey = 'last_feedback_date';
  
  SharedPreferences? _prefs;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Submit feedback
  Future<bool> submitFeedback({
    required FeedbackType type,
    required String message,
    required int rating,
    String? screenshotPath,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final feedback = FeedbackSubmission(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        message: message,
        rating: rating,
        screenshotPath: screenshotPath,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
        deviceInfo: await _getDeviceInfo(),
        appVersion: '1.0.0', // Get from app config
      );
      
      await _firestore
          .collection(_feedbackCollection)
          .doc(feedback.id)
          .set(feedback.toMap());
      
      // Update last feedback date
      await _prefs?.setString(_lastFeedbackDateKey, DateTime.now().toIso8601String());
      
      return true;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
  
  // Check if user can submit feedback (rate limiting)
  bool canSubmitFeedback() {
    final lastFeedbackDate = _prefs?.getString(_lastFeedbackDateKey);
    if (lastFeedbackDate == null) return true;
    
    final lastDate = DateTime.tryParse(lastFeedbackDate);
    if (lastDate == null) return true;
    
    // Allow one feedback per day
    final now = DateTime.now();
    final difference = now.difference(lastDate);
    return difference.inDays >= 1;
  }
  
  // Get feedback history for current user
  Future<List<FeedbackSubmission>> getFeedbackHistory() async {
    try {
      final querySnapshot = await _firestore
          .collection(_feedbackCollection)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      
      return querySnapshot.docs
          .map((doc) => FeedbackSubmission.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting feedback history: $e');
      return [];
    }
  }
  
  // Get device information for feedback context
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    return {
      'platform': 'mobile',
      'timestamp': DateTime.now().toIso8601String(),
      // Add more device info as needed
    };
  }
  
  // Feedback categories
  List<FeedbackCategory> get feedbackCategories => [
    FeedbackCategory(
      type: FeedbackType.bug,
      title: 'Bug Report',
      description: 'Report a technical issue or unexpected behavior',
      icon: Icons.bug_report,
    ),
    FeedbackCategory(
      type: FeedbackType.feature,
      title: 'Feature Request',
      description: 'Suggest a new feature or improvement',
      icon: Icons.lightbulb,
    ),
    FeedbackCategory(
      type: FeedbackType.performance,
      title: 'Performance Issue',
      description: 'Report slow loading or app crashes',
      icon: Icons.speed,
    ),
    FeedbackCategory(
      type: FeedbackType.ui,
      title: 'UI/UX Feedback',
      description: 'Share thoughts on design and user experience',
      icon: Icons.design_services,
    ),
    FeedbackCategory(
      type: FeedbackType.general,
      title: 'General Feedback',
      description: 'Share general thoughts about the app',
      icon: Icons.feedback,
    ),
  ];
}

enum FeedbackType {
  bug,
  feature,
  performance,
  ui,
  general,
}

class FeedbackCategory {
  final FeedbackType type;
  final String title;
  final String description;
  final IconData icon;
  
  FeedbackCategory({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class FeedbackSubmission {
  final String id;
  final FeedbackType type;
  final String message;
  final int rating;
  final String? screenshotPath;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final String appVersion;
  
  FeedbackSubmission({
    required this.id,
    required this.type,
    required this.message,
    required this.rating,
    this.screenshotPath,
    required this.metadata,
    required this.timestamp,
    required this.deviceInfo,
    required this.appVersion,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'message': message,
      'rating': rating,
      'screenshotPath': screenshotPath,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'deviceInfo': deviceInfo,
      'appVersion': appVersion,
    };
  }
  
  factory FeedbackSubmission.fromMap(Map<String, dynamic> map) {
    return FeedbackSubmission(
      id: map['id'] ?? '',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FeedbackType.general,
      ),
      message: map['message'] ?? '',
      rating: map['rating'] ?? 0,
      screenshotPath: map['screenshotPath'],
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      deviceInfo: Map<String, dynamic>.from(map['deviceInfo'] ?? {}),
      appVersion: map['appVersion'] ?? '1.0.0',
    );
  }
}

