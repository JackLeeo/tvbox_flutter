import Foundation
import NodeMobile

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    private var nodeChannel: NodeChannel?
    private var isRunning = false
    private var messageQueue: [String] = []
    private var completionHandlers: [String: (Result<Any, Error>) -> Void] = [:]
    
    private override init() {
        super.init()
    }
    
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        guard !isRunning else {
            completion(true)
            return
        }
        
        guard let nodePath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
            print("❌ Node.js script not found at nodejs-project/dist/main.js")
            completion(false)
            return
        }
        
        let nodeArgs = ["node", nodePath]
        
        nodeChannel = NodeChannel(start: nodeArgs) { [weak self] message in
            self?.handleMessageFromNode(message)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.isRunning = true
            self.processMessageQueue()
            completion(true)
        }
    }
    
    func stopNodeJS() {
        guard isRunning else { return }
        nodeChannel?.stop()
        isRunning = false
        messageQueue.removeAll()
        completionHandlers.removeAll()
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        if let completion = completion {
            let messageId = UUID().uuidString
            completionHandlers[messageId] = completion
            
            if let data = message.data(using: .utf8),
               var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json["messageId"] = messageId
                if let jsonData = try? JSONSerialization.data(withJSONObject: json),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    if isRunning {
                        nodeChannel?.sendMessage(jsonString)
                    } else {
                        messageQueue.append(jsonString)
                    }
                    return
                }
            }
        }
        
        if isRunning {
            nodeChannel?.sendMessage(message)
        } else {
            messageQueue.append(message)
        }
    }
    
    private func processMessageQueue() {
        while !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            nodeChannel?.sendMessage(message)
        }
    }
    
    private func handleMessageFromNode(_ message: String) {
        print("📩 Received from Node.js: \(message)")
        
        if let data = message.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messageId = json["messageId"] as? String,
           let completion = completionHandlers[messageId] {
            
            if let error = json["error"] as? String {
                completion(.failure(NSError(domain: "NodeJS", code: -1, userInfo: [NSLocalizedDescriptionKey: error])))
            } else {
                completion(.success(json["result"] ?? NSNull()))
            }
            
            completionHandlers.removeValue(forKey: messageId)
            return
        }
        
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
