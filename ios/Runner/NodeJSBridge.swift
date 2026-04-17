import Foundation
import NodeMobile
import GCDWebServer

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private var isRunning = false
    private var nodeServerPort: Int?
    private let webServer = GCDWebServer()
    private let queue = DispatchQueue(label: "com.tvbox.nodejs")
    
    private override init() {
        super.init()
        setupWebServer()
    }
    
    // MARK: - HTTP Server (GCDWebServer)
    private func setupWebServer() {
        // 处理 /onCatPawOpenPort?port=xxxx
        webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { [weak self] request in
            if request.path == "/onCatPawOpenPort" {
                if let portStr = request.query?["port"], let port = Int(portStr) {
                    self?.nodeServerPort = port
                    print("🐱 Node.js source server port: \(port)")
                }
                return GCDWebServerDataResponse(text: "OK")
            }
            return GCDWebServerResponse(statusCode: 404)
        }
        
        // 处理 /msg (接收来自 Node.js 的主动消息)
        webServer.addHandler(forMethod: "POST", path: "/msg", request: GCDWebServerDataRequest.self) { [weak self] request in
            if let dataRequest = request as? GCDWebServerDataRequest {
                let body = String(data: dataRequest.data, encoding: .utf8) ?? ""
                self?.handleMessageFromNode(body)
            }
            return GCDWebServerDataResponse(text: "OK")
        }
        
        // 启动服务器（端口 0 表示自动分配）
        do {
            try webServer.start(options: [
                GCDWebServerOption_Port: 0,
                GCDWebServerOption_BindToLocalhost: true
            ])
            let port = webServer.port
            setenv("DART_SERVER_PORT", "\(port)", 1)
            print("✅ HTTP server started on port \(port)")
        } catch {
            print("❌ Failed to start HTTP server: \(error)")
        }
    }
    
    // MARK: - Node.js Startup
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            if self.isRunning {
                DispatchQueue.main.async { completion(true) }
                return
            }
            
            guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
                print("❌ Node.js script not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            typealias NodeStartFunc = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
            guard let node_start_ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "node_start") else {
                print("❌ node_start not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            let node_start = unsafeBitCast(node_start_ptr, to: NodeStartFunc.self)
            
            let args = ["node", scriptPath]
            var cArgs = args.map { strdup($0) }
            let argc = Int32(cArgs.count)
            
            DispatchQueue.global(qos: .userInitiated).async {
                _ = node_start(argc, &cArgs)
                for ptr in cArgs { free(ptr) }
                self.isRunning = false
                print("Node.js exited")
            }
            
            Thread.sleep(forTimeInterval: 2.0)
            self.isRunning = true
            DispatchQueue.main.async { completion(true) }
        }
    }
    
    func stopNodeJS() {
        queue.async { [weak self] in
            self?.webServer.stop()
            self?.isRunning = false
        }
    }
    
    // MARK: - Message Sending (HTTP to Node source server)
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
            guard let nodePort = self?.nodeServerPort else {
                completion?(.failure(NSError(domain: "NodeJS", code: -1,
                                             userInfo: [NSLocalizedDescriptionKey: "Node service port unknown"])))
                return
            }
            
            let url = URL(string: "http://127.0.0.1:\(nodePort)/msg")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = message.data(using: .utf8)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            URLSession.shared.dataTask(with: request) { _, _, error in
                if let error = error {
                    completion?(.failure(error))
                } else {
                    completion?(.success(NSNull()))
                }
            }.resume()
        }
    }
    
    private func handleMessageFromNode(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
