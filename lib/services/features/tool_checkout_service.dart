import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';
import '../../config/firebase_config.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ToolCheckoutService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_checkouts';

  // Get all checkouts for a company
  Stream<List<ToolCheckout>> getCompanyCheckouts(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('checkoutTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get active checkouts (not returned)
  Stream<List<ToolCheckout>> getActiveCheckouts(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: CheckoutStatus.active.name)
        .orderBy('checkoutTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get overdue checkouts
  Stream<List<ToolCheckout>> getOverdueCheckouts(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: CheckoutStatus.active.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .where((checkout) => checkout.isOverdue)
            .toList());
  }

  // Get checkouts by worker
  Stream<List<ToolCheckout>> getWorkerCheckouts(String workerId) {
    return _firestore
        .collection(_collection)
        .where('workerId', isEqualTo: workerId)
        .orderBy('checkoutTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get active checkouts by worker
  Stream<List<ToolCheckout>> getActiveWorkerCheckouts(String workerId) {
    return _firestore
        .collection(_collection)
        .where('workerId', isEqualTo: workerId)
        .where('status', isEqualTo: CheckoutStatus.active.name)
        .orderBy('checkoutTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get checkouts by tool
  Stream<List<ToolCheckout>> getToolCheckouts(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .orderBy('checkoutTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get specific checkout
  Future<ToolCheckout?> getCheckout(String checkoutId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(checkoutId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolCheckout.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting checkout: $e');
      return null;
    }
  }

  // Get active checkout for a tool
  Future<ToolCheckout?> getActiveCheckoutForTool(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('status', isEqualTo: CheckoutStatus.active.name)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ToolCheckout.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting active checkout for tool: $e');
      return null;
    }
  }

  // Check out a tool
  Future<bool> checkoutTool({
    required String companyId,
    required String toolId,
    required String workerId,
    required String workerName,
    required String jobSiteId,
    required String jobSiteName,
    DateTime? expectedReturnTime,
    String? notes,
  }) async {
    try {
      // Check if tool is already checked out
      final existingCheckout = await getActiveCheckoutForTool(toolId);
      if (existingCheckout != null) {
        _snackbarService.showSnackbar(
          message: 'Tool is already checked out to ${existingCheckout.workerName}',
        );
        return false;
      }

      final checkout = ToolCheckout(
        checkoutId: _generateCheckoutId(),
        toolId: toolId,
        workerId: workerId,
        workerName: workerName,
        jobSiteId: jobSiteId,
        jobSiteName: jobSiteName,
        checkoutTime: DateTime.now(),
        expectedReturnTime: expectedReturnTime,
        actualReturnTime: null,
        status: CheckoutStatus.active,
        checkoutNotes: notes,
        returnNotes: null,
        conditionAtCheckout: null,
        conditionAtReturn: null,
        damagePhotos: [],
        metadata: {'companyId': companyId},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(checkout.toJson());

      NotificationManager().showSuccess('Tool checked out to $workerName successfully!');
      
      print('✅ Tool checked out: $toolId to $workerName');
      return true;
    } catch (e) {
      print('❌ Error checking out tool: $e');
      NotificationManager().showError('Failed to check out tool: ${e.toString()}');
      return false;
    }
  }

  // Check in a tool
  Future<bool> checkinTool({
    required String checkoutId,
    ToolCondition? returnCondition,
    String? returnNotes,
  }) async {
    try {
      final checkout = await getCheckout(checkoutId);
      if (checkout == null) {
        _snackbarService.showSnackbar(
          message: 'Checkout record not found',
        );
        return false;
      }

      if (checkout.status != CheckoutStatus.active) {
        _snackbarService.showSnackbar(
          message: 'Tool is not currently checked out',
        );
        return false;
      }

      await _firestore
          .collection(_collection)
          .doc(checkoutId)
          .update({
        'actualReturnTime': Timestamp.fromDate(DateTime.now()),
        'status': CheckoutStatus.returned.name,
        'conditionAtReturn': returnCondition?.name,
        'returnNotes': returnNotes ?? '',
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Tool checked in successfully!');
      
      print('✅ Tool checked in: ${checkout.toolId}');
      return true;
    } catch (e) {
      print('❌ Error checking in tool: $e');
      NotificationManager().showError('Failed to check in tool: ${e.toString()}');
      return false;
    }
  }

  // Mark checkout as overdue
  Future<bool> markOverdue(String checkoutId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(checkoutId)
          .update({
        'status': CheckoutStatus.overdue.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      print('✅ Checkout marked as overdue: $checkoutId');
      return true;
    } catch (e) {
      print('❌ Error marking checkout as overdue: $e');
      return false;
    }
  }

  // Mark checkout as lost
  Future<bool> markLost(String checkoutId, String notes) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(checkoutId)
          .update({
        'status': CheckoutStatus.lost.name,
        'returnNotes': notes,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Tool marked as lost');
      
      print('✅ Tool marked as lost: $checkoutId');
      return true;
    } catch (e) {
      print('❌ Error marking tool as lost: $e');
      NotificationManager().showError('Failed to mark tool as lost: ${e.toString()}');
      return false;
    }
  }

  // Extend checkout duration
  Future<bool> extendCheckout(String checkoutId, DateTime newExpectedReturn) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(checkoutId)
          .update({
        'expectedReturnTime': Timestamp.fromDate(newExpectedReturn),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Checkout extended successfully!');
      
      print('✅ Checkout extended: $checkoutId');
      return true;
    } catch (e) {
      print('❌ Error extending checkout: $e');
      NotificationManager().showError('Failed to extend checkout: ${e.toString()}');
      return false;
    }
  }

  // Get checkout history for a tool
  Future<List<ToolCheckout>> getToolCheckoutHistory(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .orderBy('checkoutTime', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error getting tool checkout history: $e');
      return [];
    }
  }

  // Get checkout statistics
  Future<Map<String, dynamic>> getCheckoutStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final checkouts = snapshot.docs
          .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
          .toList();

      final activeCheckouts = checkouts.where((c) => c.status == CheckoutStatus.active).length;
      final overdueCheckouts = checkouts.where((c) => c.isOverdue).length;
      final lostTools = checkouts.where((c) => c.status == CheckoutStatus.lost).length;

      final statusCounts = <String, int>{};
      for (final checkout in checkouts) {
        statusCounts[checkout.status.name] = (statusCounts[checkout.status.name] ?? 0) + 1;
      }

      final averageCheckoutDuration = _calculateAverageCheckoutDuration(
        checkouts.where((c) => c.actualReturnTime != null).toList()
      );

      return {
        'totalCheckouts': checkouts.length,
        'activeCheckouts': activeCheckouts,
        'overdueCheckouts': overdueCheckouts,
        'lostTools': lostTools,
        'statusBreakdown': statusCounts,
        'averageCheckoutDuration': averageCheckoutDuration,
      };
    } catch (e) {
      print('❌ Error getting checkout stats: $e');
      return {};
    }
  }

  // Process overdue checkouts (batch job)
  Future<int> processOverdueCheckouts(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: CheckoutStatus.active.name)
          .get();

      final overdueCheckouts = snapshot.docs
          .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
          .where((checkout) => checkout.isOverdue)
          .toList();

      final batch = _firestore.batch();
      for (final checkout in overdueCheckouts) {
        final docRef = _firestore.collection(_collection).doc(checkout.id);
        batch.update(docRef, {
          'status': CheckoutStatus.overdue.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      if (overdueCheckouts.isNotEmpty) {
        await batch.commit();
      }

      print('✅ Processed ${overdueCheckouts.length} overdue checkouts');
      return overdueCheckouts.length;
    } catch (e) {
      print('❌ Error processing overdue checkouts: $e');
      return 0;
    }
  }

  // Search checkouts
  Future<List<ToolCheckout>> searchCheckouts(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final checkouts = snapshot.docs
          .map((doc) => ToolCheckout.fromFirestore(doc.data(), doc.id))
          .where((checkout) =>
              checkout.workerName.toLowerCase().contains(query.toLowerCase()) ||
              checkout.jobSiteName.toLowerCase().contains(query.toLowerCase()) ||
              checkout.checkoutId.toLowerCase().contains(query.toLowerCase()) ||
              (checkout.checkoutNotes?.toLowerCase().contains(query.toLowerCase()) ?? false))
          .toList();

      return checkouts;
    } catch (e) {
      print('❌ Error searching checkouts: $e');
      return [];
    }
  }

  // Generate checkout ID
  String _generateCheckoutId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CO${timestamp.toString().substring(6)}';
  }

  // Calculate average checkout duration
  double _calculateAverageCheckoutDuration(List<ToolCheckout> completedCheckouts) {
    if (completedCheckouts.isEmpty) return 0.0;

    final totalDuration = completedCheckouts.fold<int>(0, (sum, checkout) {
      if (checkout.actualReturnTime != null) {
        return sum + checkout.actualReturnTime!.difference(checkout.checkoutTime).inHours;
      }
      return sum;
    });

    return totalDuration / completedCheckouts.length;
  }

  // Bulk check-in tools
  Future<bool> bulkCheckinTools(List<String> checkoutIds, {
    ToolCondition? condition,
    String? notes,
  }) async {
    try {
      final batch = _firestore.batch();

      for (final checkoutId in checkoutIds) {
        final docRef = _firestore.collection(_collection).doc(checkoutId);
        batch.update(docRef, {
          'actualReturnTime': Timestamp.fromDate(DateTime.now()),
          'status': CheckoutStatus.returned.name,
          'conditionAtReturn': condition?.name,
          'returnNotes': notes ?? '',
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();

      NotificationManager().showSuccess('Bulk check-in completed for ${checkoutIds.length} tools!');
      
      print('✅ Bulk check-in completed: ${checkoutIds.length} tools');
      return true;
    } catch (e) {
      print('❌ Error bulk checking in tools: $e');
      NotificationManager().showError('Failed to bulk check-in tools: ${e.toString()}');
      return false;
    }
  }
}