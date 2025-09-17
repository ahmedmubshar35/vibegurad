import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';

@lazySingleton
class ToolWarrantyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_warranties';

  // Get all warranties for a company
  Stream<List<ToolWarranty>> getCompanyWarranties(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get warranties by status
  Stream<List<ToolWarranty>> getWarrantiesByStatus(String companyId, WarrantyStatus status) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: status.name)
        .where('isActive', isEqualTo: true)
        .orderBy('endDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get expiring warranties (within specified days)
  Stream<List<ToolWarranty>> getExpiringWarranties(String companyId, {int days = 30}) {
    final cutoffDate = DateTime.now().add(Duration(days: days));
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: WarrantyStatus.active.name)
        .where('endDate', isLessThanOrEqualTo: cutoffDate.toIso8601String())
        .where('isActive', isEqualTo: true)
        .orderBy('endDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get expired warranties
  Stream<List<ToolWarranty>> getExpiredWarranties(String companyId) {
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('endDate', isLessThan: now.toIso8601String())
        .where('status', isEqualTo: WarrantyStatus.active.name)
        .where('isActive', isEqualTo: true)
        .orderBy('expiryDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get warranties by provider
  Stream<List<ToolWarranty>> getWarrantiesByProvider(String companyId, String provider) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('warrantyProvider', isEqualTo: provider)
        .where('isActive', isEqualTo: true)
        .orderBy('endDate')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get warranty for specific tool
  Future<ToolWarranty?> getToolWarranty(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ToolWarranty.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting tool warranty: $e');
      return null;
    }
  }

  // Get specific warranty
  Future<ToolWarranty?> getWarranty(String warrantyId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolWarranty.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting warranty: $e');
      return null;
    }
  }

  // Create warranty
  Future<bool> createWarranty({
    required String companyId,
    required String toolId,
    required String warrantyNumber,
    required String warrantyProvider,
    required DateTime purchaseDate,
    required DateTime startDate,
    required DateTime expiryDate,
    required WarrantyType warrantyType,
    required double warrantyValue,
    String? description,
    List<String> coverage = const [],
    List<String> exclusions = const [],
    String? contactInfo,
    String? claimProcedure,
    List<String> documentUrls = const [],
    Map<String, dynamic>? terms,
  }) async {
    try {
      final warranty = ToolWarranty(
        warrantyId: _generateWarrantyId(),
        toolId: toolId,
        warrantyProvider: warrantyProvider,
        warrantyType: warrantyType.name,
        startDate: startDate,
        endDate: expiryDate,
        warrantyNumber: warrantyNumber,
        coverageAmount: warrantyValue,
        coveredComponents: coverage,
        exclusions: exclusions,
        documentPath: documentUrls.isNotEmpty ? documentUrls.first : null,
        terms: terms ?? {},
        metadata: {'companyId': companyId, 'description': description},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await _firestore
          .collection(_collection)
          .add(warranty.toJson());

      _snackbarService.showSnackbar(
        message: 'Warranty created successfully!',
      );
      
      print('✅ Warranty created: ${warranty.warrantyId}');
      return true;
    } catch (e) {
      print('❌ Error creating warranty: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to create warranty: ${e.toString()}',
      );
      return false;
    }
  }

  // Update warranty
  Future<bool> updateWarranty(String warrantyId, ToolWarranty warranty) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update(warranty.toJson());

      _snackbarService.showSnackbar(
        message: 'Warranty updated successfully!',
      );
      
      print('✅ Warranty updated: $warrantyId');
      return true;
    } catch (e) {
      print('❌ Error updating warranty: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to update warranty: ${e.toString()}',
      );
      return false;
    }
  }

  // Extend warranty
  Future<bool> extendWarranty({
    required String warrantyId,
    required DateTime newExpiryDate,
    String? extensionReason,
    double? additionalCost,
  }) async {
    try {
      final updates = <String, dynamic>{
        'expiryDate': newExpiryDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (extensionReason != null) {
        updates['extensionReason'] = extensionReason;
      }
      if (additionalCost != null) {
        updates['extensionCost'] = additionalCost;
      }

      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update(updates);

      _snackbarService.showSnackbar(
        message: 'Warranty extended successfully!',
      );
      
      print('✅ Warranty extended: $warrantyId');
      return true;
    } catch (e) {
      print('❌ Error extending warranty: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to extend warranty: ${e.toString()}',
      );
      return false;
    }
  }

  // Create warranty claim
  Future<bool> createWarrantyClaim({
    required String warrantyId,
    required String claimReason,
    required String description,
    required String claimantName,
    String? claimantContact,
    DateTime? incidentDate,
    List<String> evidenceUrls = const [],
    double? claimAmount,
  }) async {
    try {
      final warranty = await getWarranty(warrantyId);
      if (warranty == null) {
        _snackbarService.showSnackbar(
          message: 'Warranty not found',
        );
        return false;
      }

      if (!warranty.isActive) {
        _snackbarService.showSnackbar(
          message: 'Warranty is not active',
        );
        return false;
      }

      final claim = {
        'claimId': _generateClaimId(),
        'claimDate': DateTime.now().toIso8601String(),
        'claimReason': claimReason,
        'description': description,
        'claimantName': claimantName,
        'claimantContact': claimantContact ?? '',
        'incidentDate': incidentDate?.toIso8601String(),
        'claimAmount': claimAmount,
        'status': 'submitted',
        'evidenceUrls': evidenceUrls,
        'resolution': '',
        'resolvedAt': null,
        'resolvedBy': '',
      };

      final existingClaims = (warranty.metadata['claimsHistory'] as List<dynamic>?) ?? [];
      final updatedClaimsHistory = [...existingClaims, claim];

      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update({
        'claimsHistory': updatedClaimsHistory,
        'status': WarrantyStatus.claimed.name,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Warranty claim submitted successfully!',
      );
      
      print('✅ Warranty claim created: ${claim['claimId']}');
      return true;
    } catch (e) {
      print('❌ Error creating warranty claim: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to create warranty claim: ${e.toString()}',
      );
      return false;
    }
  }

  // Update warranty claim status
  Future<bool> updateClaimStatus({
    required String warrantyId,
    required String claimId,
    required String status,
    String? resolution,
    String? resolvedBy,
  }) async {
    try {
      final warranty = await getWarranty(warrantyId);
      if (warranty == null) return false;

      final existingClaims = warranty.metadata['claimsHistory'] as List<dynamic>? ?? [];
      final updatedClaims = existingClaims.map((claim) {
        if (claim['claimId'] == claimId) {
          return {
            ...claim,
            'status': status,
            'resolution': resolution ?? claim['resolution'],
            'resolvedAt': status == 'resolved' || status == 'rejected' 
                ? DateTime.now().toIso8601String() 
                : claim['resolvedAt'],
            'resolvedBy': resolvedBy ?? claim['resolvedBy'],
          };
        }
        return claim;
      }).toList();

      // Update warranty status based on claim resolution
      String warrantyStatus = warranty.isActive ? 'active' : 'expired';
      if (status == 'resolved' || status == 'rejected') {
        warrantyStatus = warranty.isActive ? 'active' : 'expired';
      }

      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update({
        'claimsHistory': updatedClaims,
        'status': warrantyStatus,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Warranty claim status updated!',
      );
      
      print('✅ Warranty claim updated: $claimId');
      return true;
    } catch (e) {
      print('❌ Error updating claim status: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to update claim status: ${e.toString()}',
      );
      return false;
    }
  }

  // Cancel warranty
  Future<bool> cancelWarranty(String warrantyId, String reason) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update({
        'status': WarrantyStatus.cancelled.name,
        'cancellationReason': reason,
        'cancellationDate': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Warranty cancelled',
      );
      
      print('✅ Warranty cancelled: $warrantyId');
      return true;
    } catch (e) {
      print('❌ Error cancelling warranty: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to cancel warranty: ${e.toString()}',
      );
      return false;
    }
  }

  // Delete warranty (soft delete)
  Future<bool> deleteWarranty(String warrantyId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(warrantyId)
          .update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      _snackbarService.showSnackbar(
        message: 'Warranty deleted successfully!',
      );
      
      print('✅ Warranty deleted (soft): $warrantyId');
      return true;
    } catch (e) {
      print('❌ Error deleting warranty: $e');
      _snackbarService.showSnackbar(
        message: 'Failed to delete warranty: ${e.toString()}',
      );
      return false;
    }
  }

  // Get warranty statistics
  Future<Map<String, dynamic>> getWarrantyStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final warranties = snapshot.docs
          .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
          .toList();

      final totalValue = warranties.fold<double>(0.0, (sum, w) => sum + w.coverageAmount);
      final activeWarranties = warranties.where((w) => w.isActive).length;
      final expiredWarranties = warranties.where((w) => !w.isActive).length;
      final claimedWarranties = warranties.where((w) => w.metadata['status'] == 'claimed').length;

      // Expiring within 30 days
      final thirtyDaysFromNow = DateTime.now().add(const Duration(days: 30));
      final expiringWarranties = warranties.where((w) => 
          w.isActive && 
          w.endDate.isBefore(thirtyDaysFromNow)
      ).length;

      final statusCounts = <String, int>{};
      final typeCounts = <String, int>{};
      final providerCounts = <String, int>{};

      for (final warranty in warranties) {
        final status = warranty.isActive ? 'active' : 'expired';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        typeCounts[warranty.warrantyType] = (typeCounts[warranty.warrantyType] ?? 0) + 1;
        providerCounts[warranty.warrantyProvider] = (providerCounts[warranty.warrantyProvider] ?? 0) + 1;
      }

      // Claims statistics - using metadata for now since claimsHistory not in model
      final totalClaims = warranties.fold<int>(0, (sum, w) => 
          sum + ((w.metadata['claimsHistory'] as List<dynamic>?)?.length ?? 0));
      final resolvedClaims = warranties.fold<int>(0, (sum, w) {
        final claims = (w.metadata['claimsHistory'] as List<dynamic>?) ?? [];
        return sum + claims.where((c) => c['status'] == 'resolved').length;
      });

      return {
        'totalWarranties': warranties.length,
        'totalValue': totalValue,
        'activeWarranties': activeWarranties,
        'expiredWarranties': expiredWarranties,
        'claimedWarranties': claimedWarranties,
        'expiringWarranties': expiringWarranties,
        'statusBreakdown': statusCounts,
        'typeBreakdown': typeCounts,
        'providerBreakdown': providerCounts,
        'totalClaims': totalClaims,
        'resolvedClaims': resolvedClaims,
        'claimResolutionRate': totalClaims > 0 ? (resolvedClaims / totalClaims * 100) : 0.0,
        'averageWarrantyValue': warranties.isNotEmpty ? (totalValue / warranties.length) : 0.0,
      };
    } catch (e) {
      print('❌ Error getting warranty stats: $e');
      return {};
    }
  }

  // Search warranties
  Future<List<ToolWarranty>> searchWarranties(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final warranties = snapshot.docs
          .map((doc) => ToolWarranty.fromFirestore(doc.data(), doc.id))
          .where((warranty) =>
              warranty.warrantyNumber?.toLowerCase().contains(query.toLowerCase()) == true ||
              warranty.warrantyProvider.toLowerCase().contains(query.toLowerCase()) ||
              warranty.warrantyProvider.toLowerCase().contains(query.toLowerCase()) ||
              warranty.warrantyId.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return warranties;
    } catch (e) {
      print('❌ Error searching warranties: $e');
      return [];
    }
  }

  // Process warranty expirations (batch job)
  Future<int> processWarrantyExpirations(String companyId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: WarrantyStatus.active.name)
          .where('endDate', isLessThan: now.toIso8601String())
          .where('isActive', isEqualTo: true)
          .get();

      final expiredWarranties = snapshot.docs;
      final batch = _firestore.batch();

      for (final doc in expiredWarranties) {
        batch.update(doc.reference, {
          'status': WarrantyStatus.expired.name,
          'updatedAt': now.toIso8601String(),
        });
      }

      if (expiredWarranties.isNotEmpty) {
        await batch.commit();
      }

      print('✅ Processed ${expiredWarranties.length} expired warranties');
      return expiredWarranties.length;
    } catch (e) {
      print('❌ Error processing warranty expirations: $e');
      return 0;
    }
  }

  // Get warranty renewal recommendations
  Future<List<Map<String, dynamic>>> getWarrantyRenewalRecommendations(String companyId, {int days = 60}) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: days));
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: WarrantyStatus.active.name)
          .where('endDate', isLessThanOrEqualTo: cutoffDate.toIso8601String())
          .where('isActive', isEqualTo: true)
          .orderBy('endDate')
          .get();

      final recommendations = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final warranty = ToolWarranty.fromFirestore(doc.data(), doc.id);
        
        recommendations.add({
          'warrantyId': warranty.id,
          'toolId': warranty.toolId,
          'warrantyNumber': warranty.warrantyNumber,
          'provider': warranty.warrantyProvider,
          'expiryDate': warranty.endDate.toIso8601String(),
          'daysUntilExpiry': warranty.endDate.difference(DateTime.now()).inDays,
          'warrantyValue': warranty.coverageAmount,
          'hasActiveClaims': ((warranty.metadata['claimsHistory'] as List<dynamic>?) ?? []).any((c) => c['status'] == 'submitted'),
          'recommendRenewal': warranty.endDate.difference(DateTime.now()).inDays <= 30,
          'priority': warranty.endDate.difference(DateTime.now()).inDays <= 7 ? 'high' : 
                     warranty.endDate.difference(DateTime.now()).inDays <= 30 ? 'medium' : 'low',
        });
      }

      return recommendations;
    } catch (e) {
      print('❌ Error getting warranty renewal recommendations: $e');
      return [];
    }
  }

  // Generate warranty ID
  String _generateWarrantyId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'WAR${timestamp.toString().substring(6)}';
  }

  // Generate claim ID
  String _generateClaimId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'CLM${timestamp.toString().substring(6)}';
  }
}