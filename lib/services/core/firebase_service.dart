import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

import '../../config/firebase_config.dart';
import 'notification_manager.dart';

@lazySingleton
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  

  FirebaseService();

  // Firestore operations
  CollectionReference get usersCollection => 
      _firestore.collection(FirebaseConfig.usersCollection);
  
  CollectionReference get workersCollection => 
      _firestore.collection(FirebaseConfig.workersCollection);
  
  CollectionReference get companiesCollection => 
      _firestore.collection(FirebaseConfig.companiesCollection);
  
  CollectionReference get toolsCollection => 
      _firestore.collection(FirebaseConfig.toolsCollection);
  
  CollectionReference get sessionsCollection => 
      _firestore.collection(FirebaseConfig.sessionsCollection);
  
  CollectionReference get exposuresCollection => 
      _firestore.collection(FirebaseConfig.exposuresCollection);

  // Storage operations
  Reference get profileImagesRef => 
      _storage.ref().child(FirebaseConfig.profileImagesPath);
  
  Reference get toolImagesRef => 
      _storage.ref().child(FirebaseConfig.toolImagesPath);
  
  Reference get sessionImagesRef => 
      _storage.ref().child(FirebaseConfig.sessionImagesPath);

  // Generic CRUD operations
  Future<DocumentReference> addDocument(
    String collection, 
    Map<String, dynamic> data,
  ) async {
    try {
      return await _firestore.collection(collection).add(data);
    } catch (e) {
      NotificationManager().showError('Failed to add document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      NotificationManager().showError('Failed to update document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      NotificationManager().showError('Failed to delete document: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getDocument(
    String collection,
    String documentId,
  ) async {
    try {
      return await _firestore.collection(collection).doc(documentId).get();
    } catch (e) {
      NotificationManager().showError('Failed to get document: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getDocumentsStream(
    String collection, {
    Query<Object?> Function(Query<Object?> query)? queryBuilder,
  }) {
    try {
      Query<Object?> query = _firestore.collection(collection);
      
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      
      return query.snapshots();
    } catch (e) {
      NotificationManager().showError('Failed to get documents stream: $e');
      rethrow;
    }
  }

  Future<QuerySnapshot> getDocuments(
    String collection, {
    Query<Object?> Function(Query<Object?> query)? queryBuilder,
  }) async {
    try {
      Query<Object?> query = _firestore.collection(collection);
      
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      
      return await query.get();
    } catch (e) {
      NotificationManager().showError('Failed to get documents: $e');
      rethrow;
    }
  }

  // File upload operations
  Future<String> uploadFile(
    Reference storageRef,
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final fileRef = storageRef.child(fileName);
      final uploadTask = fileRef.putData(Uint8List.fromList(fileBytes));
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      NotificationManager().showError('Failed to upload file: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(Reference storageRef, String fileName) async {
    try {
      await storageRef.child(fileName).delete();
    } catch (e) {
      NotificationManager().showError('Failed to delete file: $e');
      rethrow;
    }
  }

  // Batch operations
  Future<void> batchWrite(List<BatchOperation> operations) async {
    try {
      final batch = _firestore.batch();
      
      for (final operation in operations) {
        switch (operation.type) {
          case BatchOperationType.set:
            batch.set(operation.reference, operation.data);
            break;
          case BatchOperationType.update:
            batch.update(operation.reference, operation.data!);
            break;
          case BatchOperationType.delete:
            batch.delete(operation.reference);
            break;
        }
      }
      
      await batch.commit();
    } catch (e) {
      NotificationManager().showError('Failed to perform batch operation: $e');
      rethrow;
    }
  }

  // Transaction operations
  Future<T> runTransaction<T>(Future<T> Function(Transaction) transaction) async {
    try {
      return await _firestore.runTransaction(transaction);
    } catch (e) {
      NotificationManager().showError('Failed to run transaction: $e');
      rethrow;
    }
  }
}

// Helper class for batch operations
class BatchOperation {
  final DocumentReference reference;
  final BatchOperationType type;
  final Map<String, dynamic>? data;

  BatchOperation.set(this.reference, this.data) : type = BatchOperationType.set;
  BatchOperation.update(this.reference, this.data) : type = BatchOperationType.update;
  BatchOperation.delete(this.reference) : type = BatchOperationType.delete, data = null;
}

enum BatchOperationType {
  set,
  update,
  delete,
}
