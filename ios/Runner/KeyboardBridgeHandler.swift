import Flutter
import SwiftCrypto

class KeyboardBridgeHandler: NSObject, FlutterPlugin {
    
    private static let CHANNEL_NAME = "com.relateos/keyboard_bridge"
    private static let APP_GROUP = "group.com.relateos.keyboard"
    
    static func dummyMethodToEnforceBundling(with controller: FlutterViewController) {
        // This method is an empty implementation that enforces bundling
    }
    
    static func register(with registrar: FlutterPluginRegistry) {
        let channel = FlutterMethodChannel(
            name: CHANNEL_NAME,
            binaryMessenger: registrar.messenger()
        )
        let instance = KeyboardBridgeHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func dummyMethodToEnforceBundling(with controller: FlutterViewController) {
        // This method is an empty implementation that enforces bundling
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "analyzeIntent":
            handleAnalyzeIntent(call, result: result)
            
        case "saveAnalysisLog":
            handleSaveAnalysisLog(call, result: result)
            
        case "getCachedMessages":
            handleGetCachedMessages(call, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleAnalyzeIntent(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let messages = args["messages"] as? [String],
              let userId = args["userId"] as? String,
              let targetLanguage = args["targetLanguage"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }
        
        // TODO: Call Cloudflare proxy with encrypted payload
        // For now, return mock response
        let mockResponse: [String: Any] = [
            "subtext_explanation": "Your message sounds direct and clear.",
            "suggestions": [
                ["tone": "empathetic", "text": "I hear you"],
                ["tone": "supportive", "text": "Take your time"],
                ["tone": "direct", "text": "Let's discuss"]
            ],
            "health_delta": 0.15,
            "latency_ms": 423
        ]
        
        result(mockResponse)
    }
    
    private func handleSaveAnalysisLog(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String,
              let healthScore = args["healthScore"] as? Double,
              let emotion = args["emotion"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
            return
        }
        
        // Store to shared AppGroup UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: Self.APP_GROUP) {
            var logs = sharedDefaults.array(forKey: "analysis_logs") as? [[String: Any]] ?? []
            logs.append([
                "user_id": userId,
                "health_score_snapshot": healthScore,
                "primary_emotion_detected": emotion,
                "created_at": ISO8601DateFormatter().string(from: Date())
            ])
            sharedDefaults.set(logs, forKey: "analysis_logs")
        }
        
        result(["success": true])
    }
    
    private func handleGetCachedMessages(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let sharedDefaults = UserDefaults(suiteName: Self.APP_GROUP),
           let cachedMessages = sharedDefaults.array(forKey: "cached_messages") as? [String] {
            result(cachedMessages)
        } else {
            result([String]())
        }
    }
}
