import Foundation
import NodeMobile

// 简易内嵌 HTTP 服务器（用于接收 Node.js 的回调请求）
class MiniHttpServer {
    private var serverSocket: Int32 = -1
    private(set) var port: UInt16 = 0
    var onRequest: ((String, String) -> String)?
    
    func start() throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw NSError(domain: "Socket", code: 1) }
        
        var reuse = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult >= 0 else { throw NSError(domain: "Bind", code: 2) }
        
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        getsockname(serverSocket, withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { $0 } }, &addrLen)
        port = addr.sin_port.bigEndian
        
        listen(serverSocket, 5)
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.acceptLoop()
        }
    }
    
    private func acceptLoop() {
        while serverSocket >= 0 {
            let client = accept(serverSocket, nil, nil)
            if client >= 0 {
                DispatchQueue.global(qos: .background).async {
                    self.handleClient(client)
                }
            }
        }
    }
    
    private func handleClient(_ client: Int32) {
        defer { close(client) }
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(client, &buffer, buffer.count, 0)
        guard bytesRead > 0 else { return }
        
        let requestStr = String(bytes: buffer[0..<bytesRead], encoding: .utf8) ?? ""
        let lines = requestStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }
        let method = parts[0]
        let path = parts[1]
        
        var body = ""
        if let bodyIndex = requestStr.range(of: "\r\n\r\n") {
            body = String(requestStr[bodyIndex.upperBound...])
        }
        
        let responseBody = onRequest?(path, body) ?? ""
        let response = "HTTP/1.1 200 OK\r\nContent-Length: \(responseBody.utf8.count)\r\n\r\n\(responseBody)"
        _ = response.withCString { send(client, $0, strlen($0), 0) }
    }
    
    func stop() {
        close(serverSocket)
        serverSocket = -1
    }
}

class NodeJSBridge: NSObject {
    static let shared = NodeJSBridge()
    
    private var isRunning = false
    private var nodeServerPort: Int?
    private let httpServer = MiniHttpServer()
    private let queue = DispatchQueue(label: "com.tvbox.nodejs")
    
    // C 函数原型
    typealias NodeStartFunc = @convention(c) (Int32, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
    
    private override init() {
        super.init()
        setupHttpServer()
    }
    
    private func setupHttpServer() {
        httpServer.onRequest = { [weak self] path, body in
            if path.hasPrefix("/onCatPawOpenPort") {
                if let range = path.range(of: "port=") {
                    let portStr = String(path[range.upperBound...])
                    if let port = Int(portStr) {
                        self?.nodeServerPort = port
                        print("✅ Node.js service port registered: \(port)")
                    }
                }
                return "OK"
            } else if path == "/msg" {
                self?.handleMessageFromNode(body)
                return "OK"
            }
            return ""
        }
        do {
            try httpServer.start()
            print("✅ Flutter HTTP server started on port \(httpServer.port)")
        } catch {
            print("❌ Failed to start HTTP server: \(error)")
        }
    }
    
    func startNodeJS(completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
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
            
            guard let node_start = self.getSymbol("node_start") as NodeStartFunc? else {
                print("❌ node_start function not found")
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            // 通过环境变量传递 Flutter HTTP 服务端口给 Node.js
            setenv("DART_SERVER_PORT", "\(self.httpServer.port)", 1)
            
            let args = ["node", scriptPath]
            var cArgs = args.map { strdup($0) }
            let argc = Int32(cArgs.count)
            
            DispatchQueue.global(qos: .userInitiated).async {
                let result = node_start(argc, &cArgs)
                for ptr in cArgs { free(ptr) }
                print("Node.js exited with code: \(result)")
                self.isRunning = false
            }
            
            // 等待 Node.js 初始化
            Thread.sleep(forTimeInterval: 2.0)
            self.isRunning = true
            DispatchQueue.main.async { completion(true) }
        }
    }
    
    func stopNodeJS() {
        queue.async { [weak self] in
            self?.httpServer.stop()
            self?.isRunning = false
        }
    }
    
    func sendMessage(_ message: String, completion: ((Result<Any, Error>) -> Void)? = nil) {
        queue.async { [weak self] in
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
    
    private func getSymbol<T>(_ name: String) -> T? {
        let handle = dlopen(nil, RTLD_NOW)
        defer { dlclose(handle) }
        guard let ptr = dlsym(handle, name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }
    
    private func handleMessageFromNode(_ message: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("NodeJSEvent"),
            object: nil,
            userInfo: ["message": message]
        )
    }
}
