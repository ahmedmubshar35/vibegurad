import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';
import '../../config/firebase_config.dart';
import 'tool_inventory_service.dart';
import 'tool_reservation_service.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ToolSharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ToolInventoryService _inventoryService = GetIt.instance<ToolInventoryService>();
  final ToolReservationService _reservationService = GetIt.instance<ToolReservationService>();
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _sharingCollection = 'tool_sharing_requests';
  static const String _teamCollection = 'teams';

  // Get all teams for a company
  Stream<List<Map<String, dynamic>>> getCompanyTeams(String companyId) {
    return _firestore
        .collection(_teamCollection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
            .toList());
  }

  // Get sharing requests for a team (incoming requests)
  Stream<List<Map<String, dynamic>>> getIncomingRequests(String teamId) {
    return _firestore
        .collection(_sharingCollection)
        .where('requestedFromTeamId', isEqualTo: teamId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
            .toList());
  }

  // Get sharing requests made by a team (outgoing requests)
  Stream<List<Map<String, dynamic>>> getOutgoingRequests(String teamId) {
    return _firestore
        .collection(_sharingCollection)
        .where('requestingTeamId', isEqualTo: teamId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
            .toList());
  }

  // Get active sharing agreements
  Stream<List<Map<String, dynamic>>> getActiveSharingAgreements(String teamId) {
    return _firestore
        .collection(_sharingCollection)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .where((doc) {
              final data = doc.data();
              return data['requestingTeamId'] == teamId || 
                     data['requestedFromTeamId'] == teamId;
            })
            .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
            .toList());
  }

  // Get tools available for sharing from other teams
  Future<List<Map<String, dynamic>>> getAvailableSharedTools({
    required String requestingTeamId,
    required String companyId,
    String? category,
    String? location,
  }) async {
    try {
      // Get all teams except the requesting team
      final teamsSnapshot = await _firestore
          .collection(_teamCollection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final otherTeams = teamsSnapshot.docs
          .where((doc) => doc.id != requestingTeamId)
          .toList();

      final availableTools = <Map<String, dynamic>>[];

      // Get tools from each team
      for (final teamDoc in otherTeams) {
        final teamId = teamDoc.id;
        final teamData = teamDoc.data();

        Query inventoryQuery = _firestore
            .collection('tool_inventory')
            .where('companyId', isEqualTo: companyId)
            .where('teamId', isEqualTo: teamId)
            .where('status', isEqualTo: ToolStatus.available.name)
            .where('condition', whereIn: [
              ToolCondition.excellent.name,
              ToolCondition.good.name,
            ])
            .where('isActive', isEqualTo: true);

        if (category != null) {
          inventoryQuery = inventoryQuery.where('category', isEqualTo: category);
        }

        if (location != null) {
          inventoryQuery = inventoryQuery.where('currentLocation', isEqualTo: location);
        }

        final inventorySnapshot = await inventoryQuery.get();

        for (final inventoryDoc in inventorySnapshot.docs) {
          final inventoryData = inventoryDoc.data() as Map<String, dynamic>;
          
          // Check if tool is available for sharing (no active reservations)
          final isAvailable = await _checkToolSharingAvailability(inventoryDoc.id);
          
          if (isAvailable) {
            availableTools.add({
              'inventoryId': inventoryDoc.id,
              'teamId': teamId,
              'teamName': teamData['name'] ?? 'Unknown Team',
              'teamContact': teamData['contactEmail'] ?? '',
              ...inventoryData,
            });
          }
        }
      }

      return availableTools;
    } catch (e) {
      print('❌ Error getting available shared tools: $e');
      return [];
    }
  }

  // Request tool sharing
  Future<bool> requestToolSharing({
    required String requestingTeamId,
    required String requestingTeamName,
    required String requestedFromTeamId,
    required String requestedFromTeamName,
    required String toolId,
    required String toolName,
    required String requestedByUserId,
    required String requestedByUserName,
    required DateTime requestedStartTime,
    required DateTime requestedEndTime,
    required String purpose,
    String? jobSiteId,
    String? jobSiteName,
    String? notes,
  }) async {
    try {
      // Check if tool is still available
      final isAvailable = await _checkToolSharingAvailability(toolId);
      if (!isAvailable) {
        _snackbarService.showSnackbar(
          message: 'Tool is no longer available for sharing',
        );
        return false;
      }

      final request = {
        'requestId': _generateRequestId(),
        'requestingTeamId': requestingTeamId,
        'requestingTeamName': requestingTeamName,
        'requestedFromTeamId': requestedFromTeamId,
        'requestedFromTeamName': requestedFromTeamName,
        'toolId': toolId,
        'toolName': toolName,
        'requestedByUserId': requestedByUserId,
        'requestedByUserName': requestedByUserName,
        'requestedStartTime': requestedStartTime.toIso8601String(),
        'requestedEndTime': requestedEndTime.toIso8601String(),
        'purpose': purpose,
        'jobSiteId': jobSiteId,
        'jobSiteName': jobSiteName ?? '',
        'notes': notes ?? '',
        'status': 'pending',
        'approvedBy': null,
        'approvedByName': null,
        'approvedAt': null,
        'rejectionReason': null,
        'actualStartTime': null,
        'actualEndTime': null,
        'returnCondition': null,
        'returnNotes': '',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isActive': true,
      };

      await _firestore
          .collection(_sharingCollection)
          .add(request);

      NotificationManager().showSuccess('Tool sharing request submitted!');
      
      print('✅ Tool sharing request created: ${request['requestId']}');
      return true;
    } catch (e) {
      print('❌ Error requesting tool sharing: $e');
      NotificationManager().showError('Failed to request tool sharing: ${e.toString()}');
      return false;
    }
  }

  // Approve sharing request
  Future<bool> approveSharingRequest({
    required String requestId,
    required String approvedByUserId,
    required String approvedByUserName,
  }) async {
    try {
      final requestDoc = await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        _snackbarService.showSnackbar(
          message: 'Sharing request not found',
        );
        return false;
      }

      final requestData = requestDoc.data()!;
      
      // Double-check tool availability
      final isAvailable = await _checkToolSharingAvailability(requestData['toolId']);
      if (!isAvailable) {
        _snackbarService.showSnackbar(
          message: 'Tool is no longer available for sharing',
        );
        return false;
      }

      await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .update({
        'status': 'approved',
        'approvedBy': approvedByUserId,
        'approvedByName': approvedByUserName,
        'approvedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Create reservation for the shared tool
      await _reservationService.createReservation(
        companyId: requestData['requestingTeamId'], // Use team as company context
        toolId: requestData['toolId'],
        requestedBy: requestData['requestedByUserId'],
        requestedByName: requestData['requestedByUserName'],
        reservationStart: DateTime.parse(requestData['requestedStartTime']),
        reservationEnd: DateTime.parse(requestData['requestedEndTime']),
        jobSiteId: requestData['jobSiteId'] ?? '',
        jobSiteName: requestData['jobSiteName'] ?? '',
        purpose: 'Shared tool: ${requestData['purpose']}',
        requiresApproval: false,
      );

      NotificationManager().showSuccess('Tool sharing request approved!');
      
      print('✅ Tool sharing request approved: $requestId');
      return true;
    } catch (e) {
      print('❌ Error approving sharing request: $e');
      NotificationManager().showError('Failed to approve sharing request: ${e.toString()}');
      return false;
    }
  }

  // Reject sharing request
  Future<bool> rejectSharingRequest({
    required String requestId,
    required String rejectedByUserId,
    required String rejectedByUserName,
    required String reason,
  }) async {
    try {
      await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .update({
        'status': 'rejected',
        'approvedBy': rejectedByUserId,
        'approvedByName': rejectedByUserName,
        'approvedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Tool sharing request rejected');
      
      print('✅ Tool sharing request rejected: $requestId');
      return true;
    } catch (e) {
      print('❌ Error rejecting sharing request: $e');
      NotificationManager().showError('Failed to reject sharing request: ${e.toString()}');
      return false;
    }
  }

  // Start shared tool usage
  Future<bool> startSharedToolUsage(String requestId) async {
    try {
      await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .update({
        'status': 'in_progress',
        'actualStartTime': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Shared tool usage started!');
      
      print('✅ Shared tool usage started: $requestId');
      return true;
    } catch (e) {
      print('❌ Error starting shared tool usage: $e');
      NotificationManager().showError('Failed to start shared tool usage: ${e.toString()}');
      return false;
    }
  }

  // Complete shared tool usage
  Future<bool> completeSharedToolUsage({
    required String requestId,
    ToolCondition? returnCondition,
    String? returnNotes,
  }) async {
    try {
      await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .update({
        'status': 'completed',
        'actualEndTime': DateTime.now().toIso8601String(),
        'returnCondition': returnCondition?.name,
        'returnNotes': returnNotes ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Shared tool returned successfully!');
      
      print('✅ Shared tool usage completed: $requestId');
      return true;
    } catch (e) {
      print('❌ Error completing shared tool usage: $e');
      NotificationManager().showError('Failed to complete shared tool usage: ${e.toString()}');
      return false;
    }
  }

  // Cancel sharing request
  Future<bool> cancelSharingRequest(String requestId, {String? reason}) async {
    try {
      await _firestore
          .collection(_sharingCollection)
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'rejectionReason': reason ?? 'Cancelled by requester',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Tool sharing request cancelled');
      
      print('✅ Tool sharing request cancelled: $requestId');
      return true;
    } catch (e) {
      print('❌ Error cancelling sharing request: $e');
      NotificationManager().showError('Failed to cancel sharing request: ${e.toString()}');
      return false;
    }
  }

  // Get sharing statistics
  Future<Map<String, dynamic>> getSharingStats(String teamId) async {
    try {
      final requestedSnapshot = await _firestore
          .collection(_sharingCollection)
          .where('requestingTeamId', isEqualTo: teamId)
          .get();

      final sharedSnapshot = await _firestore
          .collection(_sharingCollection)
          .where('requestedFromTeamId', isEqualTo: teamId)
          .get();

      final requestedItems = requestedSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      final sharedItems = sharedSnapshot.docs
          .map((doc) => doc.data())
          .toList();

      final allRequests = [...requestedItems, ...sharedItems];

      final statusCounts = <String, int>{};
      for (final request in allRequests) {
        final status = request['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return {
        'totalRequestsMade': requestedItems.length,
        'totalRequestsReceived': sharedItems.length,
        'activeSharing': allRequests.where((r) => r['status'] == 'in_progress').length,
        'completedSharing': allRequests.where((r) => r['status'] == 'completed').length,
        'pendingRequests': allRequests.where((r) => r['status'] == 'pending').length,
        'statusBreakdown': statusCounts,
      };
    } catch (e) {
      print('❌ Error getting sharing stats: $e');
      return {};
    }
  }

  // Search available tools for sharing
  Future<List<Map<String, dynamic>>> searchAvailableSharedTools({
    required String requestingTeamId,
    required String companyId,
    required String query,
  }) async {
    try {
      final availableTools = await getAvailableSharedTools(
        requestingTeamId: requestingTeamId,
        companyId: companyId,
      );

      return availableTools.where((tool) {
        final toolName = (tool['toolName'] as String? ?? '').toLowerCase();
        final brand = (tool['brand'] as String? ?? '').toLowerCase();
        final model = (tool['model'] as String? ?? '').toLowerCase();
        final category = (tool['category'] as String? ?? '').toLowerCase();
        final teamName = (tool['teamName'] as String? ?? '').toLowerCase();
        
        final searchQuery = query.toLowerCase();
        
        return toolName.contains(searchQuery) ||
               brand.contains(searchQuery) ||
               model.contains(searchQuery) ||
               category.contains(searchQuery) ||
               teamName.contains(searchQuery);
      }).toList();
    } catch (e) {
      print('❌ Error searching available shared tools: $e');
      return [];
    }
  }

  // Get team sharing preferences
  Future<Map<String, dynamic>?> getTeamSharingPreferences(String teamId) async {
    try {
      final teamDoc = await _firestore
          .collection(_teamCollection)
          .doc(teamId)
          .get();

      if (teamDoc.exists) {
        final data = teamDoc.data()!;
        return {
          'allowsSharing': data['allowsSharing'] ?? false,
          'sharingCategories': List<String>.from(data['sharingCategories'] ?? []),
          'sharingLocations': List<String>.from(data['sharingLocations'] ?? []),
          'requiresApproval': data['requiresSharingApproval'] ?? true,
          'maxSharingDuration': data['maxSharingDuration'] ?? 24, // hours
          'sharingNotes': data['sharingNotes'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error getting team sharing preferences: $e');
      return null;
    }
  }

  // Update team sharing preferences
  Future<bool> updateTeamSharingPreferences({
    required String teamId,
    required bool allowsSharing,
    required List<String> sharingCategories,
    required List<String> sharingLocations,
    required bool requiresApproval,
    required int maxSharingDuration,
    String? sharingNotes,
  }) async {
    try {
      await _firestore
          .collection(_teamCollection)
          .doc(teamId)
          .update({
        'allowsSharing': allowsSharing,
        'sharingCategories': sharingCategories,
        'sharingLocations': sharingLocations,
        'requiresSharingApproval': requiresApproval,
        'maxSharingDuration': maxSharingDuration,
        'sharingNotes': sharingNotes ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Sharing preferences updated!');
      
      print('✅ Team sharing preferences updated: $teamId');
      return true;
    } catch (e) {
      print('❌ Error updating sharing preferences: $e');
      NotificationManager().showError('Failed to update sharing preferences: ${e.toString()}');
      return false;
    }
  }

  // Generate request ID
  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'SHR${timestamp.toString().substring(6)}';
  }

  // Check if tool is available for sharing
  Future<bool> _checkToolSharingAvailability(String toolId) async {
    try {
      // Check if tool has active reservations
      final reservationSnapshot = await _firestore
          .collection('tool_reservations')
          .where('toolId', isEqualTo: toolId)
          .where('status', whereIn: ['confirmed', 'in_progress'])
          .get();

      if (reservationSnapshot.docs.isNotEmpty) {
        return false;
      }

      // Check if tool has active checkout
      final checkoutSnapshot = await _firestore
          .collection('tool_checkouts')
          .where('toolId', isEqualTo: toolId)
          .where('status', isEqualTo: 'checked_out')
          .get();

      if (checkoutSnapshot.docs.isNotEmpty) {
        return false;
      }

      // Check if tool has pending/active sharing requests
      final sharingSnapshot = await _firestore
          .collection(_sharingCollection)
          .where('toolId', isEqualTo: toolId)
          .where('status', whereIn: ['pending', 'approved', 'in_progress'])
          .get();

      return sharingSnapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking tool sharing availability: $e');
      return false;
    }
  }
}