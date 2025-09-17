import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';

@lazySingleton
class ToolReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_reservations';

  // Get all reservations for a company
  Stream<List<ToolReservation>> getCompanyReservations(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .orderBy('reservationStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get active reservations
  Stream<List<ToolReservation>> getActiveReservations(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: ReservationStatus.approved.name)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .where((reservation) => reservation.isActiveNow)
            .toList());
  }

  // Get upcoming reservations
  Stream<List<ToolReservation>> getUpcomingReservations(String companyId) {
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: ReservationStatus.approved.name)
        .where('reservationStart', isGreaterThan: now.toIso8601String())
        .orderBy('reservationStart')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get reservations by worker
  Stream<List<ToolReservation>> getWorkerReservations(String workerId) {
    return _firestore
        .collection(_collection)
        .where('workerId', isEqualTo: workerId)
        .orderBy('reservationStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get reservations for a specific tool
  Stream<List<ToolReservation>> getToolReservations(String toolId) {
    return _firestore
        .collection(_collection)
        .where('toolId', isEqualTo: toolId)
        .orderBy('reservationStart', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get pending approval reservations
  Stream<List<ToolReservation>> getPendingReservations(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: ReservationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get high priority reservations
  Stream<List<ToolReservation>> getHighPriorityReservations(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('priority', isEqualTo: ReservationPriority.urgent.name)
        .where('status', isEqualTo: ReservationStatus.approved.name)
        .orderBy('reservationStart')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get specific reservation
  Future<ToolReservation?> getReservation(String reservationId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(reservationId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolReservation.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting reservation: $e');
      return null;
    }
  }

  // Check tool availability for a time period
  Future<bool> checkToolAvailability({
    required String toolId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeReservationId,
  }) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('status', whereIn: [
            ReservationStatus.approved.name,
            ReservationStatus.active.name,
          ]);

      final snapshot = await query.get();

      final conflictingReservations = snapshot.docs
          .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((reservation) {
            // Exclude the reservation being updated
            if (excludeReservationId != null && reservation.id == excludeReservationId) {
              return false;
            }

            // Check for time overlap
            return startTime.isBefore(reservation.reservationEnd) &&
                   endTime.isAfter(reservation.reservationStart);
          })
          .toList();

      return conflictingReservations.isEmpty;
    } catch (e) {
      print('Error checking tool availability: $e');
      return false;
    }
  }

  // Create reservation
  Future<bool> createReservation({
    required String companyId,
    required String toolId,
    required String requestedBy,
    required String requestedByName,
    required DateTime reservationStart,
    required DateTime reservationEnd,
    required String jobSiteId,
    required String jobSiteName,
    ReservationPriority priority = ReservationPriority.normal,
    String? purpose,
    String? notes,
    bool requiresApproval = true,
  }) async {
    try {
      // Check availability first
      final isAvailable = await checkToolAvailability(
        toolId: toolId,
        startTime: reservationStart,
        endTime: reservationEnd,
      );

      if (!isAvailable) {
        _snackbarService.showSnackbar(
          message: 'Tool is not available for the requested time period',
        );
        return false;
      }

      final reservation = ToolReservation(
        reservationId: _generateReservationId(),
        toolId: toolId,
        workerId: requestedBy,
        workerName: requestedByName,
        reservationStart: reservationStart,
        reservationEnd: reservationEnd,
        status: requiresApproval ? ReservationStatus.pending : ReservationStatus.approved,
        priority: priority,
        purpose: purpose,
        notes: notes,
        approvedBy: requiresApproval ? null : requestedBy,
        approvedAt: requiresApproval ? null : DateTime.now(),
        cancelledAt: null,
        cancellationReason: null,
        metadata: {'companyId': companyId, 'jobSiteId': jobSiteId, 'jobSiteName': jobSiteName},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(reservation.toJson());

      final message = requiresApproval 
          ? 'Reservation request submitted for approval!'
          : 'Reservation confirmed successfully!';

      _snackbarService.showSnackbar(message: message);
      
      print('✅ Reservation created: ${reservation.reservationId}');
      return true;
    } catch (e) {
      print('❌ Error creating reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to create reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Approve reservation
  Future<bool> approveReservation({
    required String reservationId,
    required String approvedBy,
    required String approvedByName,
  }) async {
    try {
      final reservation = await getReservation(reservationId);
      if (reservation == null) {
        _snackbarService.showSnackbar(
          message: 'Reservation not found',
        );
        return false;
      }

      if (reservation.status != ReservationStatus.pending) {
        _snackbarService.showSnackbar(
          message: 'Reservation is not pending approval',
        );
        return false;
      }

      // Double-check availability
      final isAvailable = await checkToolAvailability(
        toolId: reservation.toolId,
        startTime: reservation.reservationStart,
        endTime: reservation.reservationEnd,
        excludeReservationId: reservationId,
      );

      if (!isAvailable) {
        _snackbarService.showSnackbar(
          message: 'Tool is no longer available for the requested time period',
        );
        return false;
      }

      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'status': ReservationStatus.approved.name,
        'approvedBy': approvedBy,
        'approvedByName': approvedByName,
        'approvedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation approved successfully!',
      );
      
      print('✅ Reservation approved: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error approving reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to approve reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Reject reservation
  Future<bool> rejectReservation({
    required String reservationId,
    required String rejectedBy,
    required String rejectedByName,
    required String reason,
  }) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'status': ReservationStatus.cancelled.name,
        'approvedBy': rejectedBy,
        'approvedByName': rejectedByName,
        'approvedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation rejected',
      );
      
      print('✅ Reservation rejected: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error rejecting reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to reject reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Start reservation (mark as in progress)
  Future<bool> startReservation(String reservationId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'status': ReservationStatus.active.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation started!',
      );
      
      print('✅ Reservation started: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error starting reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to start reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Complete reservation
  Future<bool> completeReservation(String reservationId, {String? notes}) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'status': ReservationStatus.completed.name,
        'notes': notes ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation completed!',
      );
      
      print('✅ Reservation completed: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error completing reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to complete reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Cancel reservation
  Future<bool> cancelReservation(String reservationId, {String? reason}) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'status': ReservationStatus.cancelled.name,
        'rejectionReason': reason ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation cancelled',
      );
      
      print('✅ Reservation cancelled: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error cancelling reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to cancel reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Extend reservation
  Future<bool> extendReservation(String reservationId, DateTime newEndTime) async {
    try {
      final reservation = await getReservation(reservationId);
      if (reservation == null) {
        _snackbarService.showSnackbar(
          message: 'Reservation not found',
        );
        return false;
      }

      // Check availability for extended period
      final isAvailable = await checkToolAvailability(
        toolId: reservation.toolId,
        startTime: reservation.reservationEnd,
        endTime: newEndTime,
        excludeReservationId: reservationId,
      );

      if (!isAvailable) {
        _snackbarService.showSnackbar(
          message: 'Tool is not available for the extended period',
        );
        return false;
      }

      await _firestore
          .collection(_collection)
          .doc(reservationId)
          .update({
        'reservationEnd': newEndTime.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Reservation extended successfully!',
      );
      
      print('✅ Reservation extended: $reservationId');
      return true;
    } catch (e) {
      print('❌ Error extending reservation: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to extend reservation: ${e.toString()}',
      );
      return false;
    }
  }

  // Get reservation conflicts
  Future<List<ToolReservation>> getReservationConflicts({
    required String toolId,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeReservationId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('status', whereIn: [
            ReservationStatus.approved.name,
            ReservationStatus.active.name,
          ])
          .get();

      return snapshot.docs
          .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((reservation) {
            if (excludeReservationId != null && reservation.id == excludeReservationId) {
              return false;
            }
            
            return startTime.isBefore(reservation.reservationEnd) &&
                   endTime.isAfter(reservation.reservationStart);
          })
          .toList();
    } catch (e) {
      print('❌ Error getting reservation conflicts: $e');
      return [];
    }
  }

  // Get reservation statistics
  Future<Map<String, dynamic>> getReservationStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final reservations = snapshot.docs
          .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final statusCounts = <String, int>{};
      final priorityCounts = <String, int>{};

      for (final reservation in reservations) {
        statusCounts[reservation.status.name] = (statusCounts[reservation.status.name] ?? 0) + 1;
        priorityCounts[reservation.priority.name] = (priorityCounts[reservation.priority.name] ?? 0) + 1;
      }

      final activeReservations = reservations.where((r) => r.isActiveNow).length;
      final upcomingReservations = reservations.where((r) => 
        r.status == ReservationStatus.approved && 
        r.reservationStart.isAfter(DateTime.now())
      ).length;

      return {
        'totalReservations': reservations.length,
        'activeReservations': activeReservations,
        'upcomingReservations': upcomingReservations,
        'pendingApproval': statusCounts[ReservationStatus.pending.name] ?? 0,
        'statusBreakdown': statusCounts,
        'priorityBreakdown': priorityCounts,
      };
    } catch (e) {
      print('❌ Error getting reservation stats: $e');
      return {};
    }
  }

  // Search reservations
  Future<List<ToolReservation>> searchReservations(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .get();

      final reservations = snapshot.docs
          .map((doc) => ToolReservation.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((reservation) =>
              reservation.workerName.toLowerCase().contains(query.toLowerCase()) ||
              (reservation.projectId?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
              reservation.reservationId.toLowerCase().contains(query.toLowerCase()) ||
              (reservation.purpose?.toLowerCase() ?? '').contains(query.toLowerCase()) ||
              (reservation.notes?.toLowerCase() ?? '').contains(query.toLowerCase()))
          .toList();

      return reservations;
    } catch (e) {
      print('❌ Error searching reservations: $e');
      return [];
    }
  }

  // Generate reservation ID
  String _generateReservationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'RES${timestamp.toString().substring(6)}';
  }

  // Process expired reservations (batch job)
  Future<int> processExpiredReservations(String companyId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: ReservationStatus.active.name)
          .where('reservationEnd', isLessThan: now.toIso8601String())
          .get();

      final expiredReservations = snapshot.docs;

      final batch = _firestore.batch();
      for (final doc in expiredReservations) {
        batch.update(doc.reference, {
          'status': ReservationStatus.completed.name,
          'updatedAt': now.toIso8601String(),
        });
      }

      if (expiredReservations.isNotEmpty) {
        await batch.commit();
      }

      print('✅ Processed ${expiredReservations.length} expired reservations');
      return expiredReservations.length;
    } catch (e) {
      print('❌ Error processing expired reservations: $e');
      return 0;
    }
  }
}