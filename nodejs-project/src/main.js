const { createServer } = require('http');
const axios = require('axios');
const { builtinModules } = require('module');
const vm = require('vm');
const fs = require('fs');
const path = require('path');

// 暴露所有Node.js内置模块到全局
builtinModules.forEach(mod => {
  if (!['trace_events', 'inspector'].includes(mod)) {
    globalThis[mod] = require(mod);
  }
});

// 全局变量
let currentSpider = null;
let cloudDrives = new Map();
let liveChannels = [];

// CatVodOpen 兼容层
globalThis.catServerFactory = (handler) => {
  const server = createServer(handler);
  server.listen(0, '127.0.0.1', () => {
    console.log(`CatVod server running on port ${server.address().port}`);
  });
  return server;
};

// 加载爬虫脚本
async function loadSpider(url) {
  try {
    console.log('Loading spider from:', url);
    
    if (currentSpider?.stop) {
      await currentSpider.stop();
    }
    
    const response = await axios.get(url, { timeout: 10000 });
    const scriptCode = response.data;
    
    const sandbox = {
      ...globalThis,
      console,
      require,
      module,
      exports: {},
    };
    
    vm.runInNewContext(scriptCode, sandbox, {
      filename: 'spider.js',
      timeout: 5000,
    });
    
    currentSpider = sandbox.exports.default || sandbox.exports;
    
    if (!currentSpider?.home) {
      throw new Error('Invalid spider script');
    }
    
    console.log('Spider loaded successfully');
    return true;
  } catch (e) {
    console.error('Failed to load spider:', e);
    currentSpider = null;
    return false;
  }
}

// 网盘解析器
class CloudDriveParser {
  constructor(type, config) {
    this.type = type;
    this.config = config;
  }
  
  async listFiles(path) {
    switch (this.type) {
      case 'aliyun':
        return await this.listAliyunFiles(path);
      case 'baidu':
        return await this.listBaiduFiles(path);
      case 'quark':
        return await this.listQuarkFiles(path);
      default:
        throw new Error(`Unsupported cloud drive type: ${this.type}`);
    }
  }
  
  async getPlayUrl(fileId) {
    switch (this.type) {
      case 'aliyun':
        return await this.getAliyunPlayUrl(fileId);
      case 'baidu':
        return await this.getBaiduPlayUrl(fileId);
      case 'quark':
        return await this.getQuarkPlayUrl(fileId);
      default:
        throw new Error(`Unsupported cloud drive type: ${this.type}`);
    }
  }
  
  async listAliyunFiles(path) {
    const response = await axios.post('https://api.aliyundrive.com/adrive/v3/file/list', {
      drive_id: this.config.driveId,
      parent_file_id: path || 'root',
      limit: 100,
    }, {
      headers: {
        'Authorization': `Bearer ${this.config.token}`,
        'Content-Type': 'application/json',
      },
    });
    
    return response.data.items.map(item => ({
      id: item.file_id,
      name: item.name,
      type: item.type === 'folder' ? 'folder' : 'file',
      size: item.size,
      updatedAt: item.updated_at,
    }));
  }
  
  async getAliyunPlayUrl(fileId) {
    const response = await axios.post('https://api.aliyundrive.com/v2/file/get_download_url', {
      drive_id: this.config.driveId,
      file_id: fileId,
    }, {
      headers: {
        'Authorization': `Bearer ${this.config.token}`,
        'Content-Type': 'application/json',
      },
    });
    
    return response.data.url;
  }
  
  async listBaiduFiles(path) {
    const response = await axios.get('https://pan.baidu.com/rest/2.0/xpan/file', {
      params: {
        method: 'list',
        dir: path || '/',
        limit: 100,
      },
      headers: {
        'User-Agent': 'pan.baidu.com',
        'Cookie': this.config.cookie,
      },
    });
    
    return response.data.list.map(item => ({
      id: item.fs_id.toString(),
      name: item.server_filename,
      type: item.isdir === 1 ? 'folder' : 'file',
      size: item.size,
      updatedAt: new Date(item.server_mtime * 1000).toISOString(),
    }));
  }
  
  async getBaiduPlayUrl(fileId) {
    const response = await axios.get('https://pan.baidu.com/rest/2.0/xpan/multimedia', {
      params: {
        method: 'download',
        fsids: `[${fileId}]`,
      },
      headers: {
        'User-Agent': 'pan.baidu.com',
        'Cookie': this.config.cookie,
      },
      maxRedirects: 0,
      validateStatus: status => status === 302,
    });
    
    return response.headers.location;
  }
  
  async listQuarkFiles(path) {
    const response = await axios.post('https://drive-pc.quark.cn/1/clouddrive/file/sort', {
      pdir_fid: path || '0',
      page: 1,
      size: 100,
    }, {
      headers: {
        'Cookie': this.config.cookie,
        'Content-Type': 'application/json',
      },
    });
    
    return response.data.data.list.map(item => ({
      id: item.fid,
      name: item.file_name,
      type: item.dir === true ? 'folder' : 'file',
      size: item.size,
      updatedAt: item.updated_at,
    }));
  }
  
  async getQuarkPlayUrl(fileId) {
    const response = await axios.post('https://drive-pc.quark.cn/1/clouddrive/file/download', {
      fid: fileId,
    }, {
      headers: {
        'Cookie': this.config.cookie,
        'Content-Type': 'application/json',
      },
    });
    
    return response.data.data.download_url;
  }
}

// 处理请求
async function handleRequest(action, params) {
  switch (action) {
    case 'ping':
      return 'pong';
      
    case 'loadSource':
      return await loadSpider(params.url);
      
    case 'getHomeContent':
      if (!currentSpider) throw new Error('No spider loaded');
      return await currentSpider.home();
      
    case 'getCategoryContent':
      if (!currentSpider) throw new Error('No spider loaded');
      return await currentSpider.category(params.categoryId, params.page || 1);
      
    case 'getVideoDetail':
      if (!currentSpider) throw new Error('No spider loaded');
      return await currentSpider.detail(params.videoId);
      
    case 'getPlayUrl':
      if (!currentSpider) throw new Error('No spider loaded');
      return await currentSpider.play(params.playId);
      
    case 'search':
      if (!currentSpider) throw new Error('No spider loaded');
      return await currentSpider.search(params.keyword);
      
    case 'addCloudDrive':
      const driveId = Date.now().toString();
      cloudDrives.set(driveId, new CloudDriveParser(params.type, params.config));
      return driveId;
      
    case 'listCloudDriveFiles':
      const drive = cloudDrives.get(params.driveId);
      if (!drive) throw new Error('Cloud drive not found');
      return await drive.listFiles(params.path);
      
    case 'getCloudDrivePlayUrl':
      const drive2 = cloudDrives.get(params.driveId);
      if (!drive2) throw new Error('Cloud drive not found');
      return await drive2.getPlayUrl(params.fileId);
      
    case 'getLiveChannels':
      return liveChannels;
      
    case 'getLivePlayUrl':
      const channel = liveChannels.find(c => c.id === params.channelId);
      if (!channel) throw new Error('Channel not found');
      return channel.url;
      
    default:
      throw new Error(`Unknown action: ${action}`);
  }
}

// 消息处理（修复：添加 async）
async function handleMessageFromNative(msg) {
  try {
    const data = JSON.parse(msg);
    const { messageId, action, params } = data;
    
    console.log('Received request:', action);
    
    try {
      const result = await handleRequest(action, params);
      
      const response = JSON.stringify({
        messageId: messageId,
        result: result,
      });
      
      process._linkedBinding('myaddon').sendMessageToNative(response);
    } catch (e) {
      console.error('Request error:', e);
      
      const response = JSON.stringify({
        messageId: messageId,
        error: e.message,
      });
      
      process._linkedBinding('myaddon').sendMessageToNative(response);
    }
  } catch (e) {
    console.error('Message parsing error:', e);
  }
}

// 注册回调
process._linkedBinding('myaddon').registerCallback(handleMessageFromNative);

console.log('Node.js runtime initialized');
