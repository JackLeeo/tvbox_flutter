import Foundation
import Network
import NodeMobile

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private var isRunning = false
    private var nodeServerPort: Int?
    private let httpServerQueue = DispatchQueue(label: "com.tvbox.httpserver")
    private var listener: NWListener?
    private let nodeQueue = DispatchQueue(label: "com.tvbox.nodejs")
    
    private override init() {
        super.init()
        startHttpServer()
    }
    
    // MARK: - HTTP Server (监听 /onCatPawOpenPort 和 /msg)
    private func startHttpServer() {
        httpServerQueue.async { [weak self] in
            do {
                let listener = try NWListener(using: .tcp, on: 0)
                self?.listener = listener
                
                listener.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        if let port = listener.port?.rawValue {
                            print("✅ HTTP server started on port \(port)")
                            // 保存端口到环境变量供 Node.js 读取
                            setenv("DART_SERVER_PORT", "\(port)", 1)
                        }
                    case .failed(let error):
                        print("❌ HTTP server failed: \(error)")
                    default:
                        break
                    }
                }
                
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handleConnection(connection)
                }
                
                listener.start(queue: self?.httpServerQueue ?? .main)
            } catch {
                print("❌ Failed to start HTTP server: \(error)")
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: httpServerQueue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, error in
            if let data = data, let request = String(data: data, encoding: .utf8) {
                self?.processHttpRequest(request, on: connection)
            } else {
                connection.cancel()
            }
        }
    }
    
    private func processHttpRequest(_ request: String, on connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            connection.cancel()
            return
        }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            connection.cancel()
            return
        }
        let path = parts[1]
        
        var responseBody = ""
        if path.hasPrefix("/onCatPawOpenPort") {
            if let range = path.range(of: "port=") {
                let portStr = String(path[range.upperBound...])
                if let port = Int(portStr) {
                    self.nodeServerPort = port
                    print("🐱 Node.js source server port: \(port)")
                }
            }
            responseBody = "OK"
        } else if path == "/msg" {
            if let bodyRange = request.range(of: "\r\n\r\n") {
                let body = String(request[bodyRange.upperBound...])
                self.handleMessageFromNode(body)
            }
            responseBody = "OK"
        }
        
        let response = """
        HTTP/1.1 200 OK\r
        Content-Length: \(responseBody.utf8.count)\r
        \r
        \(responseBody)
        """
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
    
    // MARK: - Node.js Startup
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        nodeQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isRunning else {
                DispatchQueue.main.async { completion(true) }
                return
            }
            
            guard let scriptPath = Bundle.main.path(forResource: "main", ofType: "js", inDirectory: "nodejs-project/dist") else {
                print("❌ Node.js script not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            typealias NodeStartFunc = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
            guard let node_start = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "node_start") else {
                print("❌ node_start not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            let startFunc = unsafeBitCast(node_start, to: NodeStartFunc.self)
            
            let args = ["node", scriptPath]
            var cArgs = args.map { strdup($0) }
            let argc = Int32(cArgs.count)
            
            DispatchQueue.global(qos: .userInitiated).async {
                _ = startFunc(argc, &cArgs)
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
        nodeQueue.async { [weak self] in
            self?.listener?.cancel()
            self?.isRunning = false
        }
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        nodeQueue.async { [weak self] in
            guard let self = self, let nodePort = self.nodeServerPort else {
                completion?(.failure(NSError(domain: "NodeJS", code: -1, userInfo: [NSLocalizedDescriptionKey: "Node service not ready"])))
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
