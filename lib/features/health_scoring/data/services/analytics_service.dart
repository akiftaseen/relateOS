import 'package:relateos/config/supabase_config.dart';
import 'package:relateos/features/health_scoring/data/models/analysis_log_model.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  
  late final _client = supabaseClient;
  
  factory AnalyticsService() {
    return _instance;
  }
  
  AnalyticsService._internal();
  
  /// Log an analysis result after keyboard suggestion
  Future<AnalysisLogModel> logAnalysis({
    required String userId,
    required double healthScore,
    required String emotion,
    String? rawText,
    int directStatementCount = 0,
    double emotionalNeedScore = 0.5,
  }) async {
    try {
      // Hash the raw text for privacy (never store actual text)
      final textHash = rawText != null
          ? sha256.convert(utf8.encode(rawText)).toString()
          : null;
      
      final logData = AnalysisLogModel(
        id: '', // Supabase will generate
        userId: userId,
        healthScoreSnapshot: healthScore,
        primaryEmotionDetected: emotion,
        createdAt: DateTime.now(),
        rawTextHash: textHash,
        directStatementCount: directStatementCount,
        emotionalNeedScore: emotionalNeedScore,
      );
      
      final response = await _client
          .from('analysis_logs')
          .insert(logData.toJson())
          .select()
          .single();
      
      return AnalysisLogModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to log analysis: $e');
    }
  }
  
  /// Fetch 7-day rolling window of analysis logs
  Future<List<AnalysisLogModel>> fetch7DayLogs(String userId) async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      final response = await _client
          .from('analysis_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: true);
      
      return (response as List<dynamic>)
          .map((e) => AnalysisLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch 7-day logs: $e');
    }
  }
  
  /// Get latest health score for user
  Future<double?> getLatestHealthScore(String userId) async {
    try {
      final response = await _client
          .from('analysis_logs')
          .select('health_score_snapshot')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return response?['health_score_snapshot'] as double?;
    } catch (e) {
      return null;
    }
  }
  
  /// Get emotion distribution over period
  Future<Map<String, int>> getEmotionDistribution(
    String userId, {
    Duration period = const Duration(days: 7),
  }) async {
    try {
      final startDate = DateTime.now().subtract(period);
      
      final response = await _client
          .from('analysis_logs')
          .select('primary_emotion_detected')
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String());
      
      final distribution = <String, int>{};
      for (final log in response as List<dynamic>) {
        final emotion = log['primary_emotion_detected'] as String;
        distribution[emotion] = (distribution[emotion] ?? 0) + 1;
      }
      
      return distribution;
    } catch (e) {
      return {};
    }
  }
  
  /// Get keyboard usage stats
  Future<KeyboardUsageStats> getKeyboardUsageStats(
    String userId, {
    Duration period = const Duration(days: 7),
  }) async {
    try {
      final startDate = DateTime.now().subtract(period);
      
      final response = await _client
          .from('analysis_logs')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String());
      
      final logs = (response as List<dynamic>)
          .map((e) => AnalysisLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
      
      if (logs.isEmpty) {
        return KeyboardUsageStats.zero();
      }
      
      final avgHealthScore = logs
          .map((l) => l.healthScoreSnapshot)
          .reduce((a, b) => a + b) / logs.length;
      
      final positiveEmotions = logs
          .where((l) => ['happy', 'understood', 'supported', '明白', '體諒']
              .contains(l.primaryEmotionDetected))
          .length;
      
      return KeyboardUsageStats(
        totalInteractions: logs.length,
        averageHealthScore: avgHealthScore,
        positiveEmotionCount: positiveEmotions,
        period: period,
      );
    } catch (e) {
      return KeyboardUsageStats.zero();
    }
  }
}

class KeyboardUsageStats {
  final int totalInteractions;
  final double averageHealthScore;
  final int positiveEmotionCount;
  final Duration period;
  
  KeyboardUsageStats({
    required this.totalInteractions,
    required this.averageHealthScore,
    required this.positiveEmotionCount,
    required this.period,
  });
  
  factory KeyboardUsageStats.zero() {
    return KeyboardUsageStats(
      totalInteractions: 0,
      averageHealthScore: 0.5,
      positiveEmotionCount: 0,
      period: const Duration(days: 7),
    );
  }
  
  int get positivityPercentage {
    if (totalInteractions == 0) return 0;
    return ((positiveEmotionCount / totalInteractions) * 100).round();
  }
}
