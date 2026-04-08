// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      preferredLanguage: json['preferred_language'] as String,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      consentKeyboardGranted: json['consent_keyboard_granted'] == null
          ? null
          : DateTime.parse(json['consent_keyboard_granted'] as String),
      baselineWeights: json['baseline_weights'] == null
          ? null
          : BaselineWeights.fromJson(
              json['baseline_weights'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'preferred_language': instance.preferredLanguage,
      'subscription_tier': instance.subscriptionTier,
      'onboarding_completed': instance.onboardingCompleted,
      'consent_keyboard_granted':
          instance.consentKeyboardGranted?.toIso8601String(),
      'baseline_weights': instance.baselineWeights,
    };

BaselineWeights _$BaselineWeightsFromJson(Map<String, dynamic> json) =>
    BaselineWeights(
      w1: (json['w1'] as num).toDouble(),
      w2: (json['w2'] as num).toDouble(),
      w3: (json['w3'] as num).toDouble(),
      quizPercentile: (json['quiz_percentile'] as num).toInt(),
    );

Map<String, dynamic> _$BaselineWeightsToJson(BaselineWeights instance) =>
    <String, dynamic>{
      'w1': instance.w1,
      'w2': instance.w2,
      'w3': instance.w3,
      'quiz_percentile': instance.quizPercentile,
    };
