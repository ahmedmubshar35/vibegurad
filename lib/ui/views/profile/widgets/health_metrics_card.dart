import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stacked/stacked.dart';
import '../../../../models/health/health_profile.dart';
import '../../../../models/health/lifetime_exposure.dart';
import '../../../../services/features/health_analytics_service.dart';
import '../../../../services/features/lifetime_exposure_service.dart';

class HealthMetricsCard extends StatelessWidget {
  final String workerId;
  
  const HealthMetricsCard({
    super.key,
    required this.workerId,
  });

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<HealthMetricsViewModel>.reactive(
      viewModelBuilder: () => HealthMetricsViewModel(),
      onViewModelReady: (model) => model.initialize(workerId),
      builder: (context, model, child) {
        if (model.isBusy) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.health_and_safety, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Health Metrics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (model.healthProfile?.havsStage != null)
                      _buildHAVSBadge(model.healthProfile!.havsStage!),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (model.riskScore != null) ...[
                  _buildRiskScoreSection(model.riskScore!),
                  const SizedBox(height: 16),
                ],

                if (model.lifetimeExposure != null) ...[
                  _buildExposureSection(model.lifetimeExposure!),
                  const SizedBox(height: 16),
                ],

                if (model.exposureHistory.isNotEmpty) ...[
                  _buildExposureChart(model.exposureHistory),
                  const SizedBox(height: 16),
                ],

                if (model.trendAnalysis != null) ...[
                  _buildTrendSection(model.trendAnalysis!),
                  const SizedBox(height: 16),
                ],

                _buildQuickActions(context, model),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHAVSBadge(HAVSStage stage) {
    Color badgeColor;
    String stageText = 'Stage ${stage.index}';
    
    switch (stage) {
      case HAVSStage.none:
        badgeColor = Colors.green;
        stageText = 'No HAVS';
        break;
      case HAVSStage.mild:
        badgeColor = Colors.yellow[700]!;
        break;
      case HAVSStage.moderate:
        badgeColor = Colors.orange;
        break;
      case HAVSStage.severe:
        badgeColor = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        stageText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRiskScoreSection(double riskScore) {
    final riskLevel = _getRiskLevel(riskScore);
    final color = _getRiskColor(riskLevel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(102)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Risk Score',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  '${riskScore.toStringAsFixed(1)}/100 - ${riskLevel.toUpperCase()}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          CircularProgressIndicator(
            value: riskScore / 100,
            backgroundColor: color.withAlpha(51),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureSection(LifetimeExposure exposure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lifetime Exposure',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'Total A(8)',
                '${exposure.cumulativeA8.toStringAsFixed(2)} m/s²',
                Icons.vibration,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Years Active',
                '${exposure.yearsOfExposure.toStringAsFixed(1)}',
                Icons.calendar_today,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'HSE Points',
                '${exposure.hsePoints}',
                Icons.point_of_sale,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Risk Level',
                exposure.riskLevel.name.toUpperCase(),
                Icons.warning,
                _getRiskColor(exposure.riskLevel.name),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureChart(List<ExposureDataPoint> history) {
    if (history.length < 2) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Exposure History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: CustomPaint(
            painter: SimpleChartPainter(
              data: history.map((e) => e.cumulativeA8).toList(),
              color: Colors.blue,
            ),
            child: Container(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendSection(Map<String, dynamic> trend) {
    final isImproving = trend['trend'] == 'improving';
    final color = isImproving ? Colors.green : Colors.red;
    final icon = isImproving ? Icons.trending_down : Icons.trending_up;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isImproving ? 'Health trend improving' : 'Health needs attention',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, HealthMetricsViewModel model) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to detailed health view
            },
            icon: const Icon(Icons.analytics, size: 16),
            label: const Text('Details'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.blue,
              backgroundColor: Colors.blue.withAlpha(51),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // Navigate to export options
            },
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.green,
              backgroundColor: Colors.green.withAlpha(51),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  String _getRiskLevel(double score) {
    if (score >= 80) return 'high';
    if (score >= 60) return 'moderate';
    if (score >= 40) return 'low';
    return 'minimal';
  }

  Color _getRiskColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
      case 'severe':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'low':
      case 'mild':
        return Colors.yellow[700]!;
      default:
        return Colors.green;
    }
  }
}

class HealthMetricsViewModel extends BaseViewModel {
  final HealthAnalyticsService _analyticsService = HealthAnalyticsService();
  final LifetimeExposureService _exposureService = LifetimeExposureService();

  HealthProfile? healthProfile;
  LifetimeExposure? lifetimeExposure;
  double? riskScore;
  List<ExposureDataPoint> exposureHistory = [];
  Map<String, dynamic>? trendAnalysis;

  Future<void> initialize(String workerId) async {
    setBusy(true);
    try {
      await Future.wait([
        _loadHealthProfile(workerId),
        _loadLifetimeExposure(workerId),
        _loadExposureHistory(workerId),
      ]);

      if (healthProfile != null && lifetimeExposure != null) {
        await _calculateRiskScore(workerId);
        await _analyzeTrends();
      }
    } catch (e) {
      // Handle error
    } finally {
      setBusy(false);
    }
  }

  Future<void> _loadHealthProfile(String workerId) async {
    try {
      // This would typically come from a health profile service
      // For now, we'll create a basic profile
      healthProfile = HealthProfile(
        workerId: workerId,
        dateOfBirth: DateTime(1990, 1, 1),
        gender: Gender.male,
        height: 175.0,
        weight: 75.0,
        dominantHand: 'right',
        hasPreExistingConditions: false,
        medicalConditions: [],
        currentMedications: [],
        smokingStatus: false,
        alcoholConsumption: 'none',
        workStartDate: DateTime(2020, 1, 1),
        previousJobsWithVibration: [],
        yearsExperienceWithVibratingTools: 3,
        currentHealthRiskScore: 0.0,
        lastHealthAssessment: DateTime.now(),
        hasHAVSSymptoms: false,
        havsStage: HAVSStage.none,
        exerciseLevel: 'moderate',
        hoursOfSleep: 8,
        stressLevel: 'moderate',
        usesPPE: true,
        emergencyContactName: '',
        emergencyContactPhone: '',
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadLifetimeExposure(String workerId) async {
    try {
      lifetimeExposure = await _exposureService.getLifetimeExposure(workerId);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _loadExposureHistory(String workerId) async {
    try {
      if (lifetimeExposure != null) {
        exposureHistory = lifetimeExposure!.riskProgressionHistory
            .take(30) // Last 30 data points
            .map((progression) => ExposureDataPoint(
                  date: progression.recordedAt,
                  cumulativeA8: progression.cumulativeA8,
                ))
            .toList();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _calculateRiskScore(String workerId) async {
    try {
      if (healthProfile != null && lifetimeExposure != null) {
        riskScore = await _analyticsService.calculateHealthRiskScore(
          healthProfile: healthProfile!,
          lifetimeExposure: lifetimeExposure!,
          recentSymptoms: [], // Would load actual recent symptoms
          recentSessions: [], // Would load actual recent sessions
        );
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _analyzeTrends() async {
    try {
      if (lifetimeExposure != null && exposureHistory.length > 1) {
        final recentAvg = exposureHistory
            .take(5)
            .map((e) => e.cumulativeA8)
            .reduce((a, b) => a + b) / 5;
        
        final olderAvg = exposureHistory
            .skip(exposureHistory.length - 5)
            .map((e) => e.cumulativeA8)
            .reduce((a, b) => a + b) / 5;

        trendAnalysis = {
          'trend': recentAvg < olderAvg ? 'improving' : 'worsening',
          'change': ((recentAvg - olderAvg) / olderAvg * 100).abs(),
        };
      }
    } catch (e) {
      // Handle error
    }
  }
}

class ExposureDataPoint {
  final DateTime date;
  final double cumulativeA8;

  ExposureDataPoint({
    required this.date,
    required this.cumulativeA8,
  });
}

class SimpleChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SimpleChartPainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withAlpha(51)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;
    
    if (range == 0) return;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SimpleChartPainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color;
  }
}
