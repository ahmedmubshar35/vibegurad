import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../models/tool/tool.dart';
import '../../config/firebase_config.dart';
import '../../enums/tool_type.dart';
import '../core/notification_manager.dart';

@lazySingleton
class ToolService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get tools for a specific company
  Stream<List<Tool>> getCompanyTools(String companyId) {
    return _firestore
        .collection(FirebaseConfig.toolsCollection)
        .where('companyId', isEqualTo: companyId)
        .where('toolActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get tools assigned to a specific worker
  Stream<List<Tool>> getWorkerTools(String workerId) {
    return _firestore
        .collection(FirebaseConfig.toolsCollection)
        .where('assignedWorkerId', isEqualTo: workerId)
        .where('toolActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get tools by category
  Stream<List<Tool>> getToolsByCategory(String companyId, String category) {
    return _firestore
        .collection(FirebaseConfig.toolsCollection)
        .where('companyId', isEqualTo: companyId)
        .where('category', isEqualTo: category)
        .where('toolActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get tools by type
  Stream<List<Tool>> getToolsByType(String companyId, ToolType type) {
    return _firestore
        .collection(FirebaseConfig.toolsCollection)
        .where('companyId', isEqualTo: companyId)
        .where('type', isEqualTo: type.name)
        .where('toolActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get a specific tool by ID
  Future<Tool?> getTool(String toolId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .get();

      if (doc.exists && doc.data() != null) {
        return Tool.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('Error getting tool: $e');
      return null;
    }
  }

  // Add a new tool
  Future<bool> addTool(Tool tool, {bool showMessage = true}) async {
    try {
      final docRef = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .add(tool.toFirestore());

      if (showMessage) {
        NotificationManager().showSuccess('Tool "${tool.name}" added successfully!');
      }
      
      print('✅ Tool added with ID: ${docRef.id}');
      return true;
    } catch (e) {
      print('❌ Error adding tool: $e');
      NotificationManager().showError('Failed to add tool: ${e.toString()}');
      return false;
    }
  }

  // Update an existing tool
  Future<bool> updateTool(String toolId, Tool tool) async {
    try {
      await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .update(tool.toFirestore());

      NotificationManager().showSuccess('Tool "${tool.name}" updated successfully!');
      
      print('✅ Tool updated: $toolId');
      return true;
    } catch (e) {
      print('❌ Error updating tool: $e');
      NotificationManager().showError('Failed to update tool: ${e.toString()}');
      return false;
    }
  }

  // Delete a tool (soft delete)
  Future<bool> deleteTool(String toolId) async {
    try {
      await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .update({
        'isActive': false,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Tool deleted successfully!');
      
      print('✅ Tool deleted (soft): $toolId');
      return true;
    } catch (e) {
      print('❌ Error deleting tool: $e');
      NotificationManager().showError('Failed to delete tool: ${e.toString()}');
      return false;
    }
  }

  // Assign tool to worker
  Future<bool> assignToolToWorker(String toolId, String workerId) async {
    try {
      await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .update({
        'assignedWorkerId': workerId,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Tool assigned successfully!');
      
      print('✅ Tool assigned: $toolId to worker: $workerId');
      return true;
    } catch (e) {
      print('❌ Error assigning tool: $e');
      NotificationManager().showError('Failed to assign tool: ${e.toString()}');
      return false;
    }
  }

  // Unassign tool from worker
  Future<bool> unassignTool(String toolId) async {
    try {
      await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .update({
        'assignedWorkerId': null,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Tool unassigned successfully!');
      
      print('✅ Tool unassigned: $toolId');
      return true;
    } catch (e) {
      print('❌ Error unassigning tool: $e');
      NotificationManager().showError('Failed to unassign tool: ${e.toString()}');
      return false;
    }
  }

  // Search tools by name or model
  Future<List<Tool>> searchTools(String companyId, String query) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .where('companyId', isEqualTo: companyId)
          .where('toolActive', isEqualTo: true)
          .get();

      final tools = snapshot.docs
          .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
          .where((tool) =>
              tool.name.toLowerCase().contains(query.toLowerCase()) ||
              tool.model.toLowerCase().contains(query.toLowerCase()) ||
              tool.brand.toLowerCase().contains(query.toLowerCase()))
          .toList();

      return tools;
    } catch (e) {
      print('❌ Error searching tools: $e');
      return [];
    }
  }

  // Get tools needing maintenance
  Future<List<Tool>> getToolsNeedingMaintenance(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .where('companyId', isEqualTo: companyId)
          .where('toolActive', isEqualTo: true)
          .get();

      final tools = snapshot.docs
          .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
          .where((tool) => tool.needsMaintenance)
          .toList();

      return tools;
    } catch (e) {
      print('❌ Error getting tools needing maintenance: $e');
      return [];
    }
  }

  // Update tool maintenance dates
  Future<bool> updateMaintenanceDate(String toolId, DateTime maintenanceDate) async {
    try {
      final nextMaintenance = maintenanceDate.add(const Duration(days: 90)); // 3 months
      
      await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .doc(toolId)
          .update({
        'lastMaintenanceDate': maintenanceDate.toIso8601String(),
        'nextMaintenanceDate': nextMaintenance.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      NotificationManager().showSuccess('Maintenance date updated successfully!');
      
      print('✅ Maintenance date updated for tool: $toolId');
      return true;
    } catch (e) {
      print('❌ Error updating maintenance date: $e');
      NotificationManager().showError('Failed to update maintenance date: ${e.toString()}');
      return false;
    }
  }

  // Get high vibration tools (above exposure action value)
  Future<List<Tool>> getHighVibrationTools(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .where('companyId', isEqualTo: companyId)
          .where('vibrationLevel', isGreaterThan: 2.5) // HSE action value
          .where('toolActive', isEqualTo: true)
          .orderBy('vibrationLevel', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('❌ Error getting high vibration tools: $e');
      return [];
    }
  }

  // Get tool usage statistics
  Future<Map<String, dynamic>> getToolUsageStats(String companyId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConfig.toolsCollection)
          .where('companyId', isEqualTo: companyId)
          .where('toolActive', isEqualTo: true)
          .get();

      final tools = snapshot.docs
          .map((doc) => Tool.fromFirestore(doc.data(), doc.id))
          .toList();

      return {
        'totalTools': tools.length,
        'assignedTools': tools.where((t) => t.isAssigned).length,
        'unassignedTools': tools.where((t) => !t.isAssigned).length,
        'highRiskTools': tools.where((t) => t.vibrationLevel > 5.0).length,
        'toolsNeedingMaintenance': tools.where((t) => t.needsMaintenance).length,
        'averageVibrationLevel': tools.isEmpty 
            ? 0.0 
            : tools.map((t) => t.vibrationLevel).reduce((a, b) => a + b) / tools.length,
      };
    } catch (e) {
      print('❌ Error getting tool usage stats: $e');
      return {};
    }
  }
}