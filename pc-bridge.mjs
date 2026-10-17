// DeepSeek Harness 电脑端桥接脚本(免管理员)
// 作用:把电脑上只监听 127.0.0.1 的 DeepSeek Harness 网页界面,
//       转发到局域网 0.0.0.0:19390,让 iPhone 上的客户端能访问。
// 用法:node pc-bridge.mjs   (或双击 start-bridge.ps1)
// 停止:Ctrl + C

import http from 'node:http';
import net from 'node:net';

const LISTEN_PORT = Number(process.env.BRIDGE_PORT || 19390);
const TARGET_HOST = process.env.BRIDGE_TARGET_HOST || '127.0.0.1';
const TARGET_PORT = Number(process.env.BRIDGE_TARGET_PORT || 19387);

const server = http.createServer((req, res) => {
  const proxy = http.request(
    {
      host: TARGET_HOST,
      port: TARGET_PORT,
      path: req.url,
      method: req.method,
      headers: req.headers,
    },
    (upstream) => {
      res.writeHead(upstream.statusCode || 502, upstream.statusMessage, upstream.headers);
      upstream.pipe(res);
    }
  );

  proxy.on('error', (err) => {
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
    }
    res.end(
      '无法连接到电脑上的 DeepSeek Harness(127.0.0.1:' + TARGET_PORT + ')。\n' +
      '请确认:1) DeepSeek Harness 正在运行;2) 本脚本先于客户端启动。\n' +
      '错误信息:' + err.message + '\n'
    );
  });

  req.pipe(proxy);
});

// WebSocket 升级请求:建立原始 TCP 隧道(聊天流式输出走这里)
server.on('upgrade', (req, socket, head) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST, () => {
    const lines = [`${req.method} ${req.url} HTTP/1.1`];
    for (let i = 0; i < req.rawHeaders.length; i += 2) {
      lines.push(`${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}`);
    }
    upstream.write(lines.join('\r\n') + '\r\n\r\n');
    if (head && head.length) upstream.write(head);
    upstream.pipe(socket);
    socket.pipe(upstream);
  });
  upstream.on('error', () => socket.destroy());
  socket.on('error', () => upstream.destroy());
});

server.listen(LISTEN_PORT, '0.0.0.0', () => {
  console.log('==============================================');
  console.log(' DeepSeek Harness 桥接已启动');
  console.log(` 本机: 0.0.0.0:${LISTEN_PORT}  ->  ${TARGET_HOST}:${TARGET_PORT}`);
  console.log(` 手机客户端里填电脑的局域网 IP,例如: 192.168.2.92:${LISTEN_PORT}`);
  console.log(' 首次运行如弹出 Windows 防火墙提示,请勾选"专用网络"并点"允许访问"');
  console.log(' 停止:按 Ctrl + C');
  console.log('==============================================');
});
