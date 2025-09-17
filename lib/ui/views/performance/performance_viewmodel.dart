import 'package:stacked/stacked.dart';
import '../../../app/app.locator.dart';
import '../../../services/features/performance_service.dart';

class PerformanceViewModel extends BaseViewModel {
  final _performanceService = locator<PerformanceService>();
  
  double get memoryUsage => _performanceService.memoryUsage;
  double get cpuUsage => _performanceService.cpuUsage;
  int get batteryLevel => _performanceService.batteryLevel;
  double get appSize => _performanceService.appSize;
  Duration get appLaunchTime => _performanceService.appLaunchTime;
  List<PerformanceMetric> get metrics => _performanceService.metrics;
  PerformanceAnalysis get performanceAnalysis => _performanceService.getPerformanceAnalysis();
  
  Future<void> refreshMetrics() async {
    setBusy(true);
    try {
      // Force update metrics
      await Future.delayed(const Duration(seconds: 1));
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }
}

