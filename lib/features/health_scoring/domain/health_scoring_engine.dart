// Health Score Formula:
// Hscore = (w1 · Cdirect/Ctotal) + (w2 · ∑Mi) - (w3 · Rescalation/Tinteractions)
//
// Where:
// - Cdirect: count of non-passive, explicit intent statements
// - Ctotal: total statements in window
// - Mi: mutually met emotional needs (0–1 per turn)
// - Rescalation: count of face-saving keywords
// - Tinteractions: conversation turns
// - w1 = 0.4, w2 = 0.35, w3 = 0.25 (adjusted ±10% based on baseline quiz)

class HealthScoringEngine {
  static const double defaultW1 = 0.4;
  static const double defaultW2 = 0.35;
  static const double defaultW3 = 0.25;
  
  // Face-saving keywords (Cantonese, English, Mandarin)
  static const List<String> faceSavingKeywords = [
    '唔使理我',    // Cantonese: don't need to care about me
    '隨便啦',      // Cantonese: whatever
    'ok la',       // English-Cantonese code-switch
    '沒關係',      // Mandarin: doesn't matter
    '隨便你',      // Cantonese: up to you
    '無所謂',      // Cantonese: doesn't matter
  ];
  
  // Emotional keywords for need mapping
  static const Map<String, double> emotionalNeedKeywords = {
    // Positive needs
    'understand': 0.8,
    'appreciate': 0.8,
    'support': 0.7,
    'care': 0.75,
    'love': 0.9,
    '明白': 0.8,     // Mandarin: understand
    '體諒': 0.8,     // Cantonese: understand/empathize
    '愛': 0.9,       // Mandarin: love
    
    // Negative needs (reduce score)
    'angry': -0.6,
    'hurt': -0.7,
    'frustrated': -0.5,
    '生氣': -0.6,    // Mandarin: angry
    '傷心': -0.7,    // Cantonese: hurt
  };
  
  final double w1;
  final double w2;
  final double w3;
  
  HealthScoringEngine({
    double? w1Override,
    double? w2Override,
    double? w3Override,
  })  : w1 = w1Override ?? defaultW1,
        w2 = w2Override ?? defaultW2,
        w3 = w3Override ?? defaultW3 {
    assert(w1 >= 0 && w1 <= 1, 'w1 must be between 0 and 1');
    assert(w2 >= 0 && w2 <= 1, 'w2 must be between 0 and 1');
    assert(w3 >= 0 && w3 <= 1, 'w3 must be between 0 and 1');
  }
  
  /// Calculate health score from a 7-day window of messages
  /// Returns score between 0.0 and 1.0
  double calculateHealthScore(List<AnalysisLog> logs7Day) {
    if (logs7Day.isEmpty) {
      return 0.5; // Neutral baseline
    }
    
    // Aggregate metrics
    double cdirect = 0;
    double ctotal = 0;
    double mutuallyMetNeeds = 0;
    double rescalation = 0;
    
    for (final log in logs7Day) {
      // Count direct statements (approximation from AI analysis)
      if (log.directStatementCount > 0) {
        cdirect += log.directStatementCount;
      }
      
      ctotal += 1; // Each message counts as 1 statement
      
      // Add emotional needs score
      mutuallyMetNeeds += log.emotionalNeedScore;
      
      // Count face-saving patterns
      rescalation += _countFaceSavingPatterns(log.rawText ?? '');
    }
    
    if (ctotal == 0) ctotal = 1; // Avoid division by zero
    
    final tinteractions = logs7Day.length.toDouble();
    if (tinteractions == 0) return 0.5;
    
    // Apply formula
    final term1 = w1 * (cdirect / ctotal);
    final term2 = w2 * (mutuallyMetNeeds / tinteractions);
    final term3 = w3 * (rescalation / tinteractions);
    
    final score = term1 + term2 - term3;
    
    // Clamp to [0, 1]
    return score.clamp(0.0, 1.0);
  }
  
  /// Count face-saving patterns in text
  int _countFaceSavingPatterns(String text) {
    int count = 0;
    final lowerText = text.toLowerCase();
    
    for (final keyword in faceSavingKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        count++;
      }
    }
    
    return count;
  }
  
  /// Extract emotional need score from message
  double extractEmotionalNeedScore(String text) {
    double score = 0.5; // Neutral baseline
    
    for (final keyword in emotionalNeedKeywords.keys) {
      if (text.toLowerCase().contains(keyword.toLowerCase())) {
        score += emotionalNeedKeywords[keyword] ?? 0;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Adjust weights based on baseline interaction style quiz
  /// percentile: user's score on the 5-question quiz (0-100)
  void adjustWeightsFromBaseline(int percentile) {
    final adjustment = (percentile - 50) / 500; // Maps to ±10% adjustment
    
    // Weights are adjusted but must remain complementary
    w1 * (1 + adjustment).clamp(0.3, 0.5);
    w2 * (1 + adjustment).clamp(0.25, 0.45);
    w3 * (1 - adjustment).clamp(0.15, 0.35);
  }
}

class AnalysisLog {
  final String id;
  final String userId;
  final double healthScoreSnapshot;
  final String primaryEmotionDetected;
  final DateTime createdAt;
  final String? rawText;
  final int directStatementCount;
  final double emotionalNeedScore;
  
  AnalysisLog({
    required this.id,
    required this.userId,
    required this.healthScoreSnapshot,
    required this.primaryEmotionDetected,
    required this.createdAt,
    this.rawText,
    this.directStatementCount = 0,
    this.emotionalNeedScore = 0.5,
  });
  
  factory AnalysisLog.fromMap(Map<String, dynamic> map) {
    return AnalysisLog(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      healthScoreSnapshot: (map['health_score_snapshot'] as num?)?.toDouble() ?? 0.5,
      primaryEmotionDetected: map['primary_emotion_detected'] as String? ?? 'neutral',
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      rawText: map['raw_text'] as String?,
      directStatementCount: map['direct_statement_count'] as int? ?? 0,
      emotionalNeedScore: (map['emotional_need_score'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
