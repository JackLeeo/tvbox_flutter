const esbuild = require('esbuild');

esbuild.build({
  entryPoints: ['src/main.js'],
  bundle: true,
  platform: 'node',
  target: 'node18',
  outfile: 'dist/main.js',
  external: ['axios', 'vm', 'fs', 'path', 'http', 'https', 'url', 'querystring', 'crypto', 'buffer', 'stream', 'util', 'events', 'zlib'],
  minify: true,
  sourcemap: false,
}).catch(() => process.exit(1));