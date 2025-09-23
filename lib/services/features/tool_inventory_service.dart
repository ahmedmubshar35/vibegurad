import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:get_it/get_it.dart';

import '../../models/tool/advanced_tool_models.dart';
import '../../config/firebase_config.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ToolInventoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SnackbarService get _snackbarService => GetIt.instance<SnackbarService>();

  static const String _collection = 'tool_inventory';

  // Get all inventory items for a company
  Stream<List<ToolInventory>> getCompanyInventory(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .orderBy('toolName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get inventory by status
  Stream<List<ToolInventory>> getInventoryByStatus(String companyId, ToolStatus status) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: status.name)
        .where('isActive', isEqualTo: true)
        .orderBy('toolName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get inventory by condition
  Stream<List<ToolInventory>> getInventoryByCondition(String companyId, ToolCondition condition) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('condition', isEqualTo: condition.name)
        .where('isActive', isEqualTo: true)
        .orderBy('toolName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get inventory by location
  Stream<List<ToolInventory>> getInventoryByLocation(String companyId, String location) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('currentLocation', isEqualTo: location)
        .where('isActive', isEqualTo: true)
        .orderBy('toolName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get low stock tools
  Stream<List<ToolInventory>> getLowStockTools(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .where((inventory) => inventory.quantity <= inventory.minStockLevel)
            .toList());
  }

  // Get tools needing maintenance
  Stream<List<ToolInventory>> getToolsNeedingMaintenance(String companyId) {
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('nextServiceDue', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .where('isActive', isEqualTo: true)
        .orderBy('nextServiceDue')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get overdue tools
  Stream<List<ToolInventory>> getOverdueTools(String companyId) {
    return _firestore
        .collection(_collection)
        .where('companyId', isEqualTo: companyId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
            .where((inventory) => inventory.isOverdue)
            .toList());
  }

  // Get specific inventory item
  Future<ToolInventory?> getInventoryItem(String inventoryId) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .get();

      if (doc.exists && doc.data() != null) {
        return ToolInventory.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting inventory item: $e');
      return null;
    }
  }

  // Get inventory by tool ID
  Future<ToolInventory?> getInventoryByToolId(String toolId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('toolId', isEqualTo: toolId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ToolInventory.fromFirestore(snapshot.docs.first.data(), snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print('Error getting inventory by tool ID: $e');
      return null;
    }
  }

  // Add new inventory item
  Future<bool> addInventoryItem(ToolInventory inventory) async {
    try {
      await _firestore
          .collection(_collection)
          .add(inventory.toJson());

      NotificationManager().showSuccess('Tool "${inventory.toolName}" added to inventory!');
      
      print('✅ Inventory item added: ${inventory.toolName}');
      return true;
    } catch (e) {
      print('❌ Error adding inventory item: $e');
      NotificationManager().showError('Failed to add inventory item: ${e.toString()}');
      return false;
    }
  }

  // Update inventory item
  Future<bool> updateInventoryItem(String inventoryId, ToolInventory inventory) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update(inventory.toJson());

      NotificationManager().showSuccess('Inventory item "${inventory.toolName}" updated!');
      
      print('✅ Inventory item updated: $inventoryId');
      return true;
    } catch (e) {
      print('❌ Error updating inventory item: $e');
      NotificationManager().showError('Failed to update inventory item: ${e.toString()}');
      return false;
    }
  }

  // Update tool status
  Future<bool> updateToolStatus(String inventoryId, ToolStatus status) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Tool status updated to ${status.name}');
      
      print('✅ Tool status updated: $inventoryId to ${status.name}');
      return true;
    } catch (e) {
      print('❌ Error updating tool status: $e');
      NotificationManager().showError('Failed to update tool status: ${e.toString()}');
      return false;
    }
  }

  // Update tool condition
  Future<bool> updateToolCondition(String inventoryId, ToolCondition condition) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update({
        'condition': condition.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Tool condition updated to ${condition.name}');
      
      print('✅ Tool condition updated: $inventoryId to ${condition.name}');
      return true;
    } catch (e) {
      print('❌ Error updating tool condition: $e');
      NotificationManager().showError('Failed to update tool condition: ${e.toString()}');
      return false;
    }
  }

  // Update tool location
  Future<bool> updateToolLocation(String inventoryId, String location) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update({
        'currentLocation': location,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Tool location updated to $location');
      
      print('✅ Tool location updated: $inventoryId to $location');
      return true;
    } catch (e) {
      print('❌ Error updating tool location: $e');
      NotificationManager().showError('Failed to update tool location: ${e.toString()}');
      return false;
    }
  }

  // Update stock quantity
  Future<bool> updateStockQuantity(String inventoryId, int newQuantity) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update({
        'quantity': newQuantity,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Stock quantity updated to $newQuantity');
      
      print('✅ Stock quantity updated: $inventoryId to $newQuantity');
      return true;
    } catch (e) {
      print('❌ Error updating stock quantity: $e');
      NotificationManager().showError('Failed to update stock quantity: ${e.toString()}');
      return false;
    }
  }

  // Delete inventory item (soft delete)
  Future<bool> deleteInventoryItem(String inventoryId) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(inventoryId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      NotificationManager().showSuccess('Inventory item deleted successfully!');
      
      print('✅ Inventory item deleted (soft): $inventoryId');
      return true;
    } catch (e) {
      print('❌ Error deleting inventory item: $e');
      NotificationManager().showError('Failed to delete inventory item: ${e.toString()}');
      return false;
    }
  }

  // Search inventory items
  Future<List<ToolInventory>> searchInventory(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
          .where((item) =>
              item.toolName.toLowerCase().contains(query.toLowerCase()) ||
              item.model.toLowerCase().contains(query.toLowerCase()) ||
              item.brand.toLowerCase().contains(query.toLowerCase()) ||
              item.serialNumber.toLowerCase().contains(query.toLowerCase()) ||
              item.barcode.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return items;
    } catch (e) {
      print('❌ Error searching inventory: $e');
      return [];
    }
  }

  // Get inventory statistics
  Future<Map<String, dynamic>> getInventoryStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('companyId', isEqualTo: companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final items = snapshot.docs
          .map((doc) => ToolInventory.fromFirestore(doc.data(), doc.id))
          .toList();

      final totalValue = items.fold<double>(0.0, (sum, item) => sum + (item.acquisitionCost * item.quantity));
      final lowStock = items.where((item) => item.quantity <= item.minStockLevel).length;
      final needsMaintenance = items.where((item) => item.nextServiceDue != null && item.nextServiceDue!.isBefore(DateTime.now())).length;
      final overdue = items.where((item) => item.isOverdue).length;

      final statusCounts = <String, int>{};
      final conditionCounts = <String, int>{};

      for (final item in items) {
        statusCounts[item.status.name] = (statusCounts[item.status.name] ?? 0) + 1;
        conditionCounts[item.condition.name] = (conditionCounts[item.condition.name] ?? 0) + 1;
      }

      return {
        'totalItems': items.length,
        'totalValue': totalValue,
        'totalQuantity': items.fold<int>(0, (sum, item) => sum + item.quantity),
        'lowStockItems': lowStock,
        'needsMaintenanceItems': needsMaintenance,
        'overdueItems': overdue,
        'statusBreakdown': statusCounts,
        'conditionBreakdown': conditionCounts,
        'averageValue': items.isEmpty ? 0.0 : totalValue / items.length,
      };
    } catch (e) {
      print('❌ Error getting inventory stats: $e');
      return {};
    }
  }

  // Bulk update stock levels
  Future<bool> bulkUpdateStock(Map<String, int> updates) async {
    try {
      final batch = _firestore.batch();

      for (final entry in updates.entries) {
        final docRef = _firestore.collection(_collection).doc(entry.key);
        batch.update(docRef, {
          'quantity': entry.value,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
      }

      await batch.commit();

      NotificationManager().showSuccess('Bulk stock update completed for ${updates.length} items!');
      
      print('✅ Bulk stock update completed: ${updates.length} items');
      return true;
    } catch (e) {
      print('❌ Error bulk updating stock: $e');
      NotificationManager().showError('Failed to bulk update stock: ${e.toString()}');
      return false;
    }
  }

  // Generate QR code data for inventory item
  String generateQRCodeData(String inventoryId, String toolId) {
    return 'vibesafe://inventory/$inventoryId?toolId=$toolId';
  }

  // Parse QR code data
  Map<String, String>? parseQRCodeData(String qrData) {
    try {
      final uri = Uri.parse(qrData);
      if (uri.scheme == 'vibesafe' && uri.host == 'inventory') {
        final inventoryId = uri.pathSegments.first;
        final toolId = uri.queryParameters['toolId'];
        
        if (inventoryId.isNotEmpty && toolId != null) {
          return {
            'inventoryId': inventoryId,
            'toolId': toolId,
          };
        }
      }
      return null;
    } catch (e) {
      print('Error parsing QR code data: $e');
      return null;
    }
  }
}