// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AnalysisLogModel _$AnalysisLogModelFromJson(Map<String, dynamic> json) =>
    AnalysisLogModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      healthScoreSnapshot: (json['health_score_snapshot'] as num).toDouble(),
      primaryEmotionDetected: json['primary_emotion_detected'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      rawTextHash: json['raw_text_hash'] as String?,
      directStatementCount:
          (json['direct_statement_count'] as num?)?.toInt() ?? 0,
      emotionalNeedScore:
          (json['emotional_need_score'] as num?)?.toDouble() ?? 0.5,
    );

Map<String, dynamic> _$AnalysisLogModelToJson(AnalysisLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'health_score_snapshot': instance.healthScoreSnapshot,
      'primary_emotion_detected': instance.primaryEmotionDetected,
      'created_at': instance.createdAt.toIso8601String(),
      'raw_text_hash': instance.rawTextHash,
      'direct_statement_count': instance.directStatementCount,
      'emotional_need_score': instance.emotionalNeedScore,
    };
