// Terminal setup
const term = new Terminal({
    fontSize: 14,
    fontFamily: 'Roboto Mono',
    cursorBlink: true,
    rows: 20,
    cols: 80,
    theme: {
        background: '#1e1e1e',
        foreground: '#ffffff',
    },
    cursorStyle: 'block',
});

const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);

// Initialize terminal
term.open(document.getElementById('terminal-container'));
fitAddon.fit();

// WebSocket setup
let ws;
let currentPrompt = '';
let commandHistory = [];
let historyIndex = -1;
let userInput = '';
let isWaitingForResponse = false;

try {
    ws = new WebSocket('ws://localhost:3000');

    ws.onopen = () => {
        term.writeln('WebSocket connection established');
    };

    ws.onmessage = (event) => {
        const data = event.data.trim();

        // Check if message starts with username@deviceName:~$
        const promptRegex = /^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+:~(?:\/[^$]*)?\$/;
        if (promptRegex.test(data)) {
            currentPrompt = data; // Update the current prompt
        } else {
            term.writeln(data); // Write output to the terminal
        }

        // Show the prompt again after the output
        writePrompt();
        isWaitingForResponse = false;
    };

    ws.onerror = () => {
        term.writeln('WebSocket connection failed - falling back to offline mode');
    };

    ws.onclose = () => {
        term.writeln('WebSocket connection closed');
    };
} catch (error) {
    term.writeln('Failed to initialize WebSocket');
}

// Function to write the current prompt
function writePrompt() {
    if (currentPrompt) {
        term.write(`\r\n${currentPrompt} `);
    }
    userInput = '';
}

// Function to refresh the current line
function refreshLine() {
    const fullLine = `${currentPrompt} ${userInput}`;
    term.write('\r' + ' '.repeat(term.cols)); // Clear the line
    term.write('\r' + fullLine); // Rewrite the line
}

// Handle terminal input
term.onKey((e) => {
    if (isWaitingForResponse) {
        return; // Block input until a response is received
    }

    const ev = e.domEvent;
    const printable = !ev.altKey && !ev.ctrlKey && !ev.metaKey;

    switch (ev.keyCode) {
        case 13: // Enter
            term.write('\r\n');
            if (userInput.trim() !== '') {
                commandHistory.push(userInput);
                historyIndex = commandHistory.length;
                ws.send(userInput); // Send only the command without the prompt
                isWaitingForResponse = true;
            }
            userInput = '';
            break;

        case 8: // Backspace
            if (userInput.length > 0) {
                userInput = userInput.slice(0, -1);
                refreshLine();
            }
            break;

        case 38: // Up arrow
            if (historyIndex > 0) {
                historyIndex--;
                userInput = commandHistory[historyIndex];
                refreshLine();
            }
            break;

        case 40: // Down arrow
            if (historyIndex < commandHistory.length - 1) {
                historyIndex++;
                userInput = commandHistory[historyIndex];
            } else {
                historyIndex = commandHistory.length;
                userInput = '';
            }
            refreshLine();
            break;

        case 67: // Ctrl+C
            if (ev.ctrlKey) {
                term.write('^C\r\n');
                writePrompt(); // Reset the prompt after a cancel
            }
            break;

        default:
            if (printable) {
                userInput += e.key;
                refreshLine();
            }
    }
});

// Resize the terminal dynamically
window.addEventListener('resize', () => {
    fitAddon.fit();
});

// Clear screen functionality
term.onData((data) => {
    if (data === '\x0C') { // Ctrl+L for clearing the screen
        term.clear();
        writePrompt();
    }
});
