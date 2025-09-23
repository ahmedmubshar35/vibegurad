import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../models/timer/timer_session.dart';
import '../../config/firebase_config.dart';
import '../core/notification_manager.dart';

@lazySingleton
class SessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get recent sessions for a user
  Stream<List<TimerSession>> getRecentSessions(String userId, {int limit = 10}) {
    return _firestore
        .collection(FirebaseConfig.sessionsCollection)
        .where('workerId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimerSession.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get sessions for today
  Stream<List<TimerSession>> getTodaySessions(String userId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection(FirebaseConfig.sessionsCollection)
        .where('workerId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimerSession.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get sessions for this week
  Stream<List<TimerSession>> getWeeklySessions(String userId) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    return _firestore
        .collection(FirebaseConfig.sessionsCollection)
        .where('workerId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TimerSession.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get total exposure time for today
  Future<Duration> getTodayTotalExposure(String userId) async {
    final sessions = await getTodaySessions(userId).first;
    var total = Duration.zero;
    for (final session in sessions) {
      if (session.endTime != null) {
        total = total + session.totalDuration;
      }
    }
    return total;
  }

  // Get total exposure time for this week
  Future<Duration> getWeeklyTotalExposure(String userId) async {
    final sessions = await getWeeklySessions(userId).first;
    var total = Duration.zero;
    for (final session in sessions) {
      if (session.endTime != null) {
        total = total + session.totalDuration;
      }
    }
    return total;
  }

  // Get exposure percentage for today based on daily limits
  Future<double> getTodayExposurePercentage(String userId) async {
    final sessions = await getTodaySessions(userId).first;
    if (sessions.isEmpty) return 0.0;

    // Calculate total exposure in minutes
    final totalMinutes = sessions.fold(0, (total, session) {
      if (session.endTime != null) {
        return total + session.totalMinutes;
      }
      return total;
    });

    // Use 480 minutes (8 hours) as default daily limit if no specific tool limit
    const defaultDailyLimit = 480;
    
    return (totalMinutes / defaultDailyLimit * 100).clamp(0, 100);
  }

  // Get session statistics
  Future<Map<String, dynamic>> getSessionStats(String userId) async {
    try {
      final todayTotal = await getTodayTotalExposure(userId);
      final weeklyTotal = await getWeeklyTotalExposure(userId);
      final todayPercentage = await getTodayExposurePercentage(userId);

      return {
        'todayMinutes': todayTotal.inMinutes,
        'weeklyMinutes': weeklyTotal.inMinutes,
        'todayPercentage': todayPercentage,
      };
    } catch (e) {
      print('❌ Error getting session stats: $e');
      return {
        'todayMinutes': 0,
        'weeklyMinutes': 0,
        'todayPercentage': 0.0,
      };
    }
  }
}