import 'package:flutter/services.dart';

class KeyboardBridgeService {
  static const String channelName = 'com.relateos/keyboard_bridge';
  static const String appGroup = 'group.com.relateos.keyboard';
  
  static final KeyboardBridgeService _instance = KeyboardBridgeService._internal();
  
  late final MethodChannel _channel;
  
  factory KeyboardBridgeService() {
    return _instance;
  }
  
  KeyboardBridgeService._internal() {
    _channel = const MethodChannel(channelName);
  }
  
  // Analyze intent from keyboard capture
  Future<AnalysisResponse> analyzeIntent({
    required String userId,
    required List<String> messages,
    required String targetLanguage,
    String? currentDraft,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'analyzeIntent',
        {
          'user_id': userId,
          'messages': messages,
          'target_language': targetLanguage,
          'current_draft': currentDraft,
        },
      );
      
      if (result == null) {
        throw Exception('No response from keyboard bridge');
      }
      
      return AnalysisResponse.fromMap(result.cast<String, dynamic>());
    } catch (e) {
      rethrow;
    }
  }
  
  // Save analysis log to keyboard app group storage
  Future<bool> saveAnalysisLog({
    required String userId,
    required double healthScore,
    required String emotion,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'saveAnalysisLog',
        {
          'user_id': userId,
          'health_score': healthScore,
          'emotion': emotion,
        },
      );
      
      return result?['success'] as bool? ?? false;
    } catch (e) {
      rethrow;
    }
  }
  
  // Get cached messages from keyboard
  Future<List<String>> getCachedMessages() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'getCachedMessages',
      );
      
      return result?.cast<String>() ?? [];
    } catch (e) {
      rethrow;
    }
  }
  
  // Encrypt payload with AES-256-GCM
  Future<String> encryptPayload(
    String payload,
    String encryptionKey,
  ) async {
    // TODO: Implement AES-256-GCM encryption
    // For MVP, using dummy implementation
    return payload;
  }
  
  // Decrypt response
  Future<String> decryptPayload(
    String encryptedPayload,
    String encryptionKey,
  ) async {
    // TODO: Implement AES-256-GCM decryption
    // For MVP, using dummy implementation
    return encryptedPayload;
  }
}

class AnalysisResponse {
  final String subtextExplanation;
  final List<SuggestionItem> suggestions;
  final double healthDelta;
  final int latencyMs;
  
  AnalysisResponse({
    required this.subtextExplanation,
    required this.suggestions,
    required this.healthDelta,
    required this.latencyMs,
  });
  
  factory AnalysisResponse.fromMap(Map<String, dynamic> map) {
    return AnalysisResponse(
      subtextExplanation: map['subtext_explanation'] ?? '',
      suggestions: (map['suggestions'] as List<dynamic>?)
          ?.map((e) => SuggestionItem.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      healthDelta: (map['health_delta'] as num?)?.toDouble() ?? 0.0,
      latencyMs: map['latency_ms'] as int? ?? 0,
    );
  }
}

class SuggestionItem {
  final String text;
  final String tone;
  
  SuggestionItem({
    required this.text,
    required this.tone,
  });
  
  factory SuggestionItem.fromMap(Map<String, dynamic> map) {
    return SuggestionItem(
      text: map['text'] ?? '',
      tone: map['tone'] ?? 'neutral',
    );
  }
}
