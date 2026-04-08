import 'package:json_annotation/json_annotation.dart';

part 'analysis_log_model.g.dart';

@JsonSerializable()
class AnalysisLogModel {
  final String id;
  
  @JsonKey(name: 'user_id')
  final String userId;
  
  @JsonKey(name: 'health_score_snapshot')
  final double healthScoreSnapshot;
  
  @JsonKey(name: 'primary_emotion_detected')
  final String primaryEmotionDetected;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'raw_text_hash')
  final String? rawTextHash;
  
  @JsonKey(name: 'direct_statement_count')
  final int directStatementCount;
  
  @JsonKey(name: 'emotional_need_score')
  final double emotionalNeedScore;

  AnalysisLogModel({
    required this.id,
    required this.userId,
    required this.healthScoreSnapshot,
    required this.primaryEmotionDetected,
    required this.createdAt,
    this.rawTextHash,
    this.directStatementCount = 0,
    this.emotionalNeedScore = 0.5,
  });

  factory AnalysisLogModel.fromJson(Map<String, dynamic> json) =>
      _$AnalysisLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnalysisLogModelToJson(this);

  AnalysisLogModel copyWith({
    String? id,
    String? userId,
    double? healthScoreSnapshot,
    String? primaryEmotionDetected,
    DateTime? createdAt,
    String? rawTextHash,
    int? directStatementCount,
    double? emotionalNeedScore,
  }) {
    return AnalysisLogModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      healthScoreSnapshot: healthScoreSnapshot ?? this.healthScoreSnapshot,
      primaryEmotionDetected: primaryEmotionDetected ?? this.primaryEmotionDetected,
      createdAt: createdAt ?? this.createdAt,
      rawTextHash: rawTextHash ?? this.rawTextHash,
      directStatementCount: directStatementCount ?? this.directStatementCount,
      emotionalNeedScore: emotionalNeedScore ?? this.emotionalNeedScore,
    );
  }
}
