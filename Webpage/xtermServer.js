const WebSocket = require('ws');
const { exec } = require('child_process');

// Create a WebSocket server on port 3000
const wss = new WebSocket.Server({ port: 3000 }, () => {
  console.log('WebSocket server is running on ws://localhost:3000');
});

wss.on('connection', (ws) => {
  console.log('New client connected');

  // Listen for messages from the client
  ws.on('message', (message) => {
    console.log(`Received command: ${message}`);

    // Execute the command in the terminal
    exec(message, (error, stdout, stderr) => {
      if (error) {
        ws.send(`Error: ${error.message}`);
        return;
      }
      if (stderr) {
        ws.send(`Stderr: ${stderr}`);
        return;
      }
      ws.send(`Output: ${stdout}`);
    });
  });

  ws.on('close', () => {
    console.log('Client disconnected');
  });

  ws.on('error', (err) => {
    console.error(`WebSocket error: ${err}`);
  });
});
