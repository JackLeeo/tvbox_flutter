const {createServer} = require('http');
const axios = require('axios');
const {builtinModules} = require('module');

// 暴露所有Node.js内置模块到全局（原项目逻辑）
builtinModules.forEach(mod => {
  if (!['trace_events'].includes(mod)) {
    globalThis[mod] = require(mod);
  }
});

// 全局变量（原项目逻辑）
let sourceModule;
let nativeServerPort = 0;
let messageQueue = [];
let isReady = false;

// CatVodOpen 兼容层（原项目逻辑，100% 保留）
globalThis.catServerFactory = handle => {
  let port = 0;
  const server = createServer((req, res) => {
    handle(req, res);
  });
  server.on('listening', () => {
    port = server.address().port;
    axios.get(`http://127.0.0.1:${globalThis.catDartServerPort()}/onCatPawOpenPort?port=${port}`);
    console.log('Run on ' + port);
  });
  server.on('close', () => {
    console.log('Close on ' + port);
  });
  return server;
};

globalThis.catDartServerPort = () => {
  return nativeServerPort;
};

// 加载Spider脚本（原项目逻辑，100% 保留）
function loadScript(path) {
  try {
    const indexJSPath = `${path}/index.js`;
    const indexConfigJSPath = `${path}/index.config.js`;
    delete require.cache[require.resolve(indexJSPath)];
    delete require.cache[require.resolve(indexConfigJSPath)];
    sourceModule = require(indexJSPath);
    const config = require(indexConfigJSPath);
    sourceModule.start(config.default || config);
  } catch (e) {
    console.log(e);
  }
}

// 全局异常捕获（原项目逻辑）
process.on('uncaughtException', function (err) {
  console.error('Caught exception: ' + err);
});

// 发送消息到原生（适配NodeMobile）
function sendMessageToNative(message) {
  if (isReady) {
    globalThis.sendToNative(message);
  } else {
    messageQueue.push(message);
  }
}

// 处理来自原生的消息（适配NodeMobile）
function handleMessageFromNative(message) {
  console.log('Message from Native:', message);
  try {
    const data = JSON.parse(message);
    switch (data.action) {
      case 'run':
        await sourceModule?.stop?.();
        loadScript(data.path);
        break;
      case 'nativeServerPort':
        nativeServerPort = data.port;
        break;
      default:
        break;
    }
  } catch (e) {
    console.log(e);
  }
}

// NodeMobile框架初始化
globalThis.onNativeReady = () => {
  console.log('Node.js runtime initialized');
  isReady = true;
  // 处理队列消息
  while (messageQueue.length > 0) {
    sendMessageToNative(messageQueue.shift());
  }
  // 通知原生就绪（原项目逻辑）
  sendMessageToNative('ready');
};

// 监听原生消息（NodeMobile标准API）
globalThis.onMessageFromNative = handleMessageFromNative;
