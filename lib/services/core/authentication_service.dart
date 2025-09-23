import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/core/user.dart' as app_user;
import '../../enums/user_role.dart';
import '../../config/firebase_config.dart';
import '../features/timer_service.dart';
import 'notification_manager.dart';

@lazySingleton
class AuthenticationService with ListenableServiceMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  NavigationService get _navigationService => GetIt.instance<NavigationService>();
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();
  late final TimerService _timerService = GetIt.instance<TimerService>();

  // Current user state
  final ReactiveValue<app_user.User?> _currentUser = ReactiveValue<app_user.User?>(null);
  app_user.User? get currentUser => _currentUser.value;
  
  bool get isAuthenticated => _auth.currentUser != null;
  User? get firebaseUser => _auth.currentUser;

  AuthenticationService() {
    listenToReactiveValues([_currentUser]);
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _setCurrentUser(user.uid);
      } else {
        _currentUser.value = null;
      }
    });
  }

  Future<void> _setCurrentUser(String uid) async {
    try {
      print('🔍 Loading user data for UID: $uid');
      final doc = await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        final userData = doc.data()!;
        final user = app_user.User.fromFirestore(userData, uid);
        _currentUser.value = user;
        print('✅ User data loaded from Firestore: ${userData['email']}');
        print('🆔 User ID after loading: ${user.id}');
        
        // Fix existing users without company ID
        if (_currentUser.value != null && _currentUser.value!.companyId == null) {
          await _fixUserCompanyId(uid, _currentUser.value!);
        }
        
        // Set the current user in TimerService
        if (_currentUser.value != null) {
          print('🔧 Setting user in TimerService: ${_currentUser.value!.id}');
          _timerService.setCurrentUser(_currentUser.value!);
        }
      } else {
        print('❌ User document not found in Firestore for UID: $uid');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  // Create or get company by name
  Future<String> _createOrGetCompany(String companyName) async {
    try {
      print('🏢 Creating or getting company: $companyName');
      
      // First, try to find existing company by name
      final existingCompanies = await _firestore
          .collection(FirebaseConfig.companiesCollection)
          .where('name', isEqualTo: companyName)
          .limit(1)
          .get();

      if (existingCompanies.docs.isNotEmpty) {
        final companyId = existingCompanies.docs.first.id;
        print('✅ Found existing company: $companyName (ID: $companyId)');
        return companyId;
      }

      // Create new company
      final companyData = {
        'name': companyName,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      final docRef = await _firestore
          .collection(FirebaseConfig.companiesCollection)
          .add(companyData);

      print('✅ Created new company: $companyName (ID: ${docRef.id})');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating/getting company: $e');
      // Return a fallback company ID
      return 'default_company_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // Fix existing user without company ID
  Future<void> _fixUserCompanyId(String uid, app_user.User user) async {
    try {
      print('🔧 Fixing company ID for existing user: ${user.email}');
      
      String companyName = user.companyName ?? '${user.firstName} ${user.lastName} Company';
      String companyId = await _createOrGetCompany(companyName);
      
      // Update user with company ID
      final updatedUser = user.copyWith(
        companyId: companyId,
        companyName: companyName,
        updatedAt: DateTime.now(),
      );
      
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(uid)
          .update(updatedUser.toFirestore());
      
      // Update current user
      _currentUser.value = updatedUser;
      
      print('✅ Fixed company ID for user: ${user.email} -> Company: $companyName (ID: $companyId)');
    } catch (e) {
      print('❌ Error fixing user company ID: $e');
    }
  }

  // Register new user
  Future<bool> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? companyName,
  }) async {
    try {
      print('🔧 Starting user registration for: $email');
      
      // Create Firebase Auth user
      User? firebaseUser;
      try {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        firebaseUser = credential.user;
      } catch (authError) {
        print('❌ Firebase Auth creation failed: $authError');
        // Check if user was actually created despite the error
        await Future.delayed(Duration(milliseconds: 500));
        firebaseUser = _auth.currentUser;
        if (firebaseUser?.email != email) {
          rethrow;
        }
        print('✅ User was created despite error, continuing...');
      }

      if (firebaseUser == null) {
        print('❌ Firebase Auth failed - no user credential');
        return false;
      }

      print('✅ Firebase Auth user created with UID: ${firebaseUser.uid}');

      // Create or get company ID
      String? companyId;
      if (companyName != null && companyName.isNotEmpty) {
        companyId = await _createOrGetCompany(companyName);
      } else {
        // For workers without company, create a default company
        companyId = await _createOrGetCompany('${firstName} ${lastName} Company');
      }

      // Create user document
      final user = app_user.User(
        id: firebaseUser.uid,  // Set the Firebase UID as the user ID
        email: email,
        firstName: firstName,
        lastName: lastName,
        role: role,
        companyId: companyId,
        companyName: companyName ?? '${firstName} ${lastName} Company',
        isEmailVerified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
       );

      print('🔧 Attempting to save user document to Firestore...');
      print('📝 User data: ${user.toFirestore()}');
      print('🆔 User ID: ${user.id}');

      // Save to Firestore
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(firebaseUser.uid)
          .set(user.toFirestore());

      print('✅ SUCCESS: User document saved to Firestore!');
      print('📍 Collection: ${FirebaseConfig.usersCollection}');
      print('📍 Document ID: ${firebaseUser.uid}');

      // Set current user
      _currentUser.value = user;

      NotificationManager().showSuccess('Account created successfully!');

      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      _handleAuthError(e);
      return false;
    } catch (e) {
      print('❌ Registration Error: ${e.toString()}');
      NotificationManager().showError('Registration failed: ${e.toString()}');
      return false;
    }
  }

  // Sign in user
  Future<bool> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      print('🔧 Starting sign-in for: $email');
      
      User? firebaseUser;
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        firebaseUser = credential.user;
      } catch (authError) {
        print('❌ Firebase Auth sign-in failed: $authError');
        // Check if user was actually signed in despite the error
        await Future.delayed(Duration(milliseconds: 500));
        firebaseUser = _auth.currentUser;
        if (firebaseUser?.email != email) {
          rethrow;
        }
        print('✅ User signed in despite error, continuing...');
      }

      if (firebaseUser == null) {
        print('❌ Sign-in failed - no user');
        return false;
      }

      print('✅ Sign-in successful for UID: ${firebaseUser.uid}');

      NotificationManager().showSuccess('Welcome back!');

      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      _handleAuthError(e);
      return false;
    } catch (e) {
      print('❌ Sign-in Error: ${e.toString()}');
      NotificationManager().showError('Sign in failed: ${e.toString()}');
      return false;
    }
  }

  // Sign out user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser.value = null;
    } catch (e) {
      NotificationManager().showError('Sign out failed: ${e.toString()}');
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      NotificationManager().showSuccess('Password reset email sent!');
      return true;
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
      return false;
    } catch (e) {
      NotificationManager().showError('Failed to send reset email: ${e.toString()}');
      return false;
    }
  }
  
  // Deactivate user account (soft delete)
  Future<bool> deactivateAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        NotificationManager().showError('No user logged in');
        return false;
      }
      
      // Update user status in Firestore
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(user.uid)
          .update({
            'isActive': false,
            'deactivatedAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      
      // Sign out the user
      await signOut();
      
      NotificationManager().showSuccess('Account deactivated successfully. You can reactivate by logging in again.');
      
      return true;
    } catch (e) {
      print('❌ Failed to deactivate account: $e');
      NotificationManager().showError('Failed to deactivate account: ${e.toString()}');
      return false;
    }
  }
  
  // Delete user account permanently
  Future<bool> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        NotificationManager().showError('No user logged in');
        return false;
      }
      
      // Re-authenticate user before deletion
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        NotificationManager().showError('Invalid password. Please try again.');
        return false;
      }
      
      // Delete user data from Firestore
      await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(user.uid)
          .delete();
      
      // Delete user sessions
      final sessions = await _firestore
          .collection(FirebaseConfig.sessionsCollection)
          .where('workerId', isEqualTo: user.uid)
          .get();
      
      for (final doc in sessions.docs) {
        await doc.reference.delete();
      }
      
      // Delete Firebase Auth account
      await user.delete();
      
      _currentUser.value = null;
      
      NotificationManager().showSuccess('Account deleted permanently.');
      
      return true;
    } catch (e) {
      print('❌ Failed to delete account: $e');
      NotificationManager().showError('Failed to delete account: ${e.toString()}');
      return false;
    }
  }
  
  // Reactivate deactivated account
  Future<bool> reactivateAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      // Check if account is deactivated
      final doc = await _firestore
          .collection(FirebaseConfig.usersCollection)
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data()?['isActive'] == false) {
        // Reactivate the account
        await _firestore
            .collection(FirebaseConfig.usersCollection)
            .doc(user.uid)
            .update({
              'isActive': true,
              'reactivatedAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            });
        
        NotificationManager().showSuccess('Welcome back! Your account has been reactivated.');
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Failed to reactivate account: $e');
      return false;
    }
  }

  // Handle Firebase Auth errors
  void _handleAuthError(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'weak-password':
        message = 'Password is too weak';
        break;
      case 'email-already-in-use':
        message = 'Email is already registered';
        break;
      case 'user-not-found':
        message = 'No account found with this email';
        break;
      case 'wrong-password':
        message = 'Incorrect password';
        break;
      case 'user-disabled':
        message = 'Account has been disabled';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Try again later';
        break;
      case 'invalid-email':
        message = 'Invalid email address';
        break;
      default:
        message = 'Authentication failed: ${e.message}';
    }
    NotificationManager().showError(message);
  }

  // Role checks
  bool get isWorker => currentUser?.role == UserRole.worker;
  bool get isManager => currentUser?.role == UserRole.manager;
  bool get isAdmin => currentUser?.role == UserRole.admin;

  bool hasRole(UserRole role) => currentUser?.role == role;
  
  bool canAccess(String feature) {
    if (currentUser == null) return false;
    
    switch (feature) {
      case 'admin_panel':
        return isAdmin;
      case 'manager_dashboard':
        return isManager || isAdmin;
      case 'tool_management':
        return isManager || isAdmin;
      case 'reports':
        return isManager || isAdmin;
      default:
        return true;
    }
  }
}