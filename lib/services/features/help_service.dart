import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';

@lazySingleton
class HelpService with ListenableServiceMixin {
  
  // FAQ Categories and Questions
  List<HelpCategory> get helpCategories => [
    HelpCategory(
      title: 'Getting Started',
      icon: Icons.play_circle_outline,
      questions: [
        HelpQuestion(
          question: 'How do I scan a tool?',
          answer: 'Open the camera view and point your phone at the power tool. The AI will automatically recognize the tool and start the safety timer.',
        ),
        HelpQuestion(
          question: 'What if the tool isn\'t recognized?',
          answer: 'You can manually select the tool from the catalog or use the QR/barcode scanner if available on the tool.',
        ),
        HelpQuestion(
          question: 'How do I start a timer session?',
          answer: 'After scanning a tool, the timer will start automatically. You can also manually start a session from the home screen.',
        ),
      ],
    ),
    HelpCategory(
      title: 'Safety & Exposure',
      icon: Icons.health_and_safety,
      questions: [
        HelpQuestion(
          question: 'What are vibration exposure limits?',
          answer: 'Exposure limits are based on OSHA standards. For example, a jackhammer has a daily limit of 2.5 hours, while a drill can be used for up to 8 hours.',
        ),
        HelpQuestion(
          question: 'What happens when I reach the limit?',
          answer: 'The app will show warnings at 50%, 80%, and 95% of your limit. At 100%, the timer stops and you must take a mandatory rest period.',
        ),
        HelpQuestion(
          question: 'How is my daily exposure calculated?',
          answer: 'Your exposure is calculated using the A(8) method, which considers both vibration magnitude and duration for each tool used.',
        ),
      ],
    ),
    HelpCategory(
      title: 'App Features',
      icon: Icons.settings,
      questions: [
        HelpQuestion(
          question: 'Does the app work offline?',
          answer: 'Yes! The app works offline for up to 7 days. Your data will sync automatically when you have an internet connection.',
        ),
        HelpQuestion(
          question: 'How do I change the theme?',
          answer: 'Go to Settings > App Settings and choose between Light, Dark, or System theme.',
        ),
        HelpQuestion(
          question: 'Can I change the language?',
          answer: 'Yes, go to Settings > App Settings and select your preferred language from the available options.',
        ),
      ],
    ),
    HelpCategory(
      title: 'Troubleshooting',
      icon: Icons.build,
      questions: [
        HelpQuestion(
          question: 'The camera isn\'t working',
          answer: 'Check that you\'ve granted camera permissions in your device settings. Restart the app if the issue persists.',
        ),
        HelpQuestion(
          question: 'Notifications aren\'t showing',
          answer: 'Ensure notification permissions are enabled in your device settings and in the app\'s notification settings.',
        ),
        HelpQuestion(
          question: 'Data isn\'t syncing',
          answer: 'Check your internet connection. If you\'re offline, data will sync when connection is restored.',
        ),
      ],
    ),
    HelpCategory(
      title: 'Account & Data',
      icon: Icons.account_circle,
      questions: [
        HelpQuestion(
          question: 'How do I export my data?',
          answer: 'Go to Reports > Export Data to generate a CSV file with your exposure history and health metrics.',
        ),
        HelpQuestion(
          question: 'Is my data secure?',
          answer: 'Yes, all data is encrypted and stored securely. We follow HIPAA compliance standards for health data protection.',
        ),
        HelpQuestion(
          question: 'Can I delete my account?',
          answer: 'Yes, go to Settings > Account Management > Delete Account. This will permanently remove all your data.',
        ),
      ],
    ),
  ];
  
  // Contact information
  ContactInfo get contactInfo => ContactInfo(
    email: 'support@vibeguard.com',
    phone: '+1 (555) 123-4567',
    website: 'https://vibeguard.com/support',
    businessHours: 'Monday - Friday, 8:00 AM - 6:00 PM EST',
  );
  
  // Search functionality
  List<HelpQuestion> searchQuestions(String query) {
    if (query.isEmpty) return [];
    
    final results = <HelpQuestion>[];
    final lowerQuery = query.toLowerCase();
    
    for (final category in helpCategories) {
      for (final question in category.questions) {
        if (question.question.toLowerCase().contains(lowerQuery) ||
            question.answer.toLowerCase().contains(lowerQuery)) {
          results.add(question);
        }
      }
    }
    
    return results;
  }
}

class HelpCategory {
  final String title;
  final IconData icon;
  final List<HelpQuestion> questions;
  
  HelpCategory({
    required this.title,
    required this.icon,
    required this.questions,
  });
}

class HelpQuestion {
  final String question;
  final String answer;
  
  HelpQuestion({
    required this.question,
    required this.answer,
  });
}

class ContactInfo {
  final String email;
  final String phone;
  final String website;
  final String businessHours;
  
  ContactInfo({
    required this.email,
    required this.phone,
    required this.website,
    required this.businessHours,
  });
}

