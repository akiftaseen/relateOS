import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final String id;
  
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'preferred_language')
  final String preferredLanguage;
  
  @JsonKey(name: 'subscription_tier')
  final String subscriptionTier;
  
  @JsonKey(name: 'onboarding_completed')
  final bool onboardingCompleted;
  
  @JsonKey(name: 'consent_keyboard_granted')
  final DateTime? consentKeyboardGranted;
  
  @JsonKey(name: 'baseline_weights')
  final BaselineWeights? baselineWeights;

  UserModel({
    required this.id,
    required this.createdAt,
    required this.preferredLanguage,
    this.subscriptionTier = 'free',
    this.onboardingCompleted = false,
    this.consentKeyboardGranted,
    this.baselineWeights,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    String? id,
    DateTime? createdAt,
    String? preferredLanguage,
    String? subscriptionTier,
    bool? onboardingCompleted,
    DateTime? consentKeyboardGranted,
    BaselineWeights? baselineWeights,
  }) {
    return UserModel(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      consentKeyboardGranted: consentKeyboardGranted ?? this.consentKeyboardGranted,
      baselineWeights: baselineWeights ?? this.baselineWeights,
    );
  }
}

@JsonSerializable()
class BaselineWeights {
  final double w1;
  final double w2;
  final double w3;
  
  @JsonKey(name: 'quiz_percentile')
  final int quizPercentile;

  BaselineWeights({
    required this.w1,
    required this.w2,
    required this.w3,
    required this.quizPercentile,
  });

  factory BaselineWeights.fromJson(Map<String, dynamic> json) =>
      _$BaselineWeightsFromJson(json);

  Map<String, dynamic> toJson() => _$BaselineWeightsToJson(this);
}
