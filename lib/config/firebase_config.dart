class FirebaseConfig {
  // Collection Names
  static const String usersCollection = 'users';
  static const String workersCollection = 'workers';
  static const String companiesCollection = 'companies';
  static const String toolsCollection = 'tools';
  static const String toolCategoriesCollection = 'tool_categories';
  static const String sessionsCollection = 'sessions';
  static const String exposuresCollection = 'exposures';
  static const String restPeriodsCollection = 'rest_periods';
  static const String alertsCollection = 'alerts';
  static const String reportsCollection = 'reports';
  static const String locationsCollection = 'locations';
  
  // Storage Paths
  static const String profileImagesPath = 'profile_images';
  static const String toolImagesPath = 'tool_images';
  static const String sessionImagesPath = 'session_images';
  static const String reportFilesPath = 'report_files';
  
  // Security Rules
  static const Map<String, dynamic> firestoreRules = {
    'rules_version': '2',
    'service': 'cloud.firestore',
    'match': {
      'databases/{database}/documents': {
        // Users can read/write their own data
        'users/{userId}': {
          'allow': 'read, write',
          'if': 'request.auth != null && request.auth.uid == userId'
        },
        // Workers can read/write their own data
        'workers/{workerId}': {
          'allow': 'read, write',
          'if': 'request.auth != null && request.auth.uid == workerId'
        },
        // Companies - read by company members, write by admins
        'companies/{companyId}': {
          'allow': 'read',
          'if': 'request.auth != null && request.auth.token.companyId == companyId'
        },
        // Tools - read by company members, write by admins
        'tools/{toolId}': {
          'allow': 'read',
          'if': 'request.auth != null && request.auth.token.companyId == resource.data.companyId'
        },
        // Sessions - read/write by the worker who created them
        'sessions/{sessionId}': {
          'allow': 'read, write',
          'if': 'request.auth != null && request.auth.uid == resource.data.workerId'
        },
        // Exposures - read/write by the worker who created them
        'exposures/{exposureId}': {
          'allow': 'read, write',
          'if': 'request.auth != null && request.auth.uid == resource.data.workerId'
        }
      }
    }
  };
  
  // Indexes for better query performance
  static const List<Map<String, dynamic>> firestoreIndexes = [
    {
      'collectionGroup': 'sessions',
      'queryScope': 'COLLECTION',
      'fields': [
        {'fieldPath': 'workerId', 'order': 'ASCENDING'},
        {'fieldPath': 'startTime', 'order': 'DESCENDING'}
      ]
    },
    {
      'collectionGroup': 'exposures',
      'queryScope': 'COLLECTION',
      'fields': [
        {'fieldPath': 'workerId', 'order': 'ASCENDING'},
        {'fieldPath': 'date', 'order': 'DESCENDING'}
      ]
    },
    {
      'collectionGroup': 'tools',
      'queryScope': 'COLLECTION',
      'fields': [
        {'fieldPath': 'companyId', 'order': 'ASCENDING'},
        {'fieldPath': 'category', 'order': 'ASCENDING'}
      ]
    }
  ];
}
