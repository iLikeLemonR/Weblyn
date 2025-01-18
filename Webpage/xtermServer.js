const express = require('express');
const pty = require('node-pty');
const path = require('path');
const WebSocket = require('ws');

const app = express();

// Serve the frontend
app.use(express.static(path.join(__dirname, 'public')));

// Create WebSocket server
const wss = new WebSocket.Server({ noServer: true });

wss.on('connection', (ws) => {
  // Create a pseudo-terminal
  const shell = pty.spawn(process.env.SHELL || '/bin/bash', [], {
    name: 'xterm-256color',
    cols: 80,
    rows: 30,
    cwd: process.env.HOME,
    env: process.env,
  });

  // Send shell output to WebSocket client
  shell.on('data', (data) => {
    ws.send(data);
  });

  // Send WebSocket client input to the shell
  ws.on('message', (message) => {
    shell.write(message);
  });

  // Handle terminal resize
  ws.on('resize', (size) => {
    if (shell) shell.resize(size.cols, size.rows);
  });

  // Clean up on WebSocket close
  ws.on('close', () => {
    shell.kill();
  });
});

// Upgrade HTTP server for WebSocket
const server = app.listen(3000, () => {
  console.log('Server running at http://localhost:3000');
});

server.on('upgrade', (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});
