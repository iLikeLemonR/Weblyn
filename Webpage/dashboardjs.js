// <----------Start of Theme Switching code------------>
document.querySelectorAll('.dropdown-item[data-theme]').forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const theme = e.target.getAttribute('data-theme');
        document.body.classList.remove('dark-mode', 'light-mode', 'retro', 'solarized', "high-contrast", "pastel-dream");
        document.body.classList.add(theme);
        updateTerminalTheme(theme);
    });
});
// <----------End of Theme Switching code------------>
// <----------Start of XTerm code------------>
// Terminal setup
const term = new Terminal({
    fontSize: 14,
    fontFamily: 'Roboto Mono',
    cursorBlink: true,
    rows: 20,
    cols: 80,
    theme: {
        background: '#1e1e1e',
        foreground: '#ffffff'
    }
});

const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);

// Initialize terminal
term.open(document.getElementById('terminal-container'));
fitAddon.fit();

// Terminal themes
const terminalThemes = {
    'dark-mode': { background: '#1e1e1e', foreground: '#ffffff' },
    'light-mode': { background: '#f1f9e9', foreground: '#000000' },
    'retro': { background: '#F6DCAC', foreground: '#01204E' },
    'solarized': { background: '#073642', foreground: '#839496' },
    'high-contrast': { background: '#333333', foreground: '#ffffff' },
    'pastel-dream': { background: '#ffe4e1', foreground: '#2f4f4f' }
};

function updateTerminalTheme(themeName) {
    term.setOption('theme', terminalThemes[themeName]);
}

// Offline terminal functionality
let commandHistory = [];
let historyIndex = 0;
let currentLine = '';
let prompt = '$ ';

// Initialize terminal with prompt
term.write('\r\n' + prompt);

// Command handling
function handleCommand(command) {
    if (command.trim() !== '') {
        commandHistory.push(command);
        historyIndex = commandHistory.length;

        // Simple command processing
        let output = '';
        switch (command.trim().toLowerCase()) {
            case 'help':
                output = 'Available commands:\n\r' +
                        'help     - Show this help message\n\r' +
                        'clear    - Clear the terminal\n\r' +
                        'date     - Show current date and time\n\r' +
                        'echo     - Echo the input\n\r' +
                        'history  - Show command history\n\r';
                break;
            case 'clear':
                term.clear();
                return;
            case 'date':
                output = new Date().toString();
                break;
            case 'history':
                output = commandHistory.map((cmd, i) => `${i + 1}  ${cmd}`).join('\n\r');
                break;
            default:
                if (command.trim().toLowerCase().startsWith('echo ')) {
                    output = command.substring(5);
                } else {
                    output = `Command not found: ${command}`;
                }
        }
        term.write('\r\n' + output);
    }
    term.write('\r\n' + prompt);
}

// Handle terminal input
term.onKey((e) => {
    const ev = e.domEvent;
    const printable = !ev.altKey && !ev.ctrlKey && !ev.metaKey;

    if (ev.keyCode === 13) { // Enter key
        term.write('\r\n');
        handleCommand(currentLine);
        currentLine = '';
    } else if (ev.keyCode === 8) { // Backspace
        if (currentLine.length > 0) {
            currentLine = currentLine.substr(0, currentLine.length - 1);
            term.write('\b \b');
        }
    } else if (ev.keyCode === 38) { // Up arrow
        if (historyIndex > 0) {
            historyIndex--;
            currentLine = commandHistory[historyIndex];
            term.write('\r\x1B[K' + prompt + currentLine);
        }
    } else if (ev.keyCode === 40) { // Down arrow
        if (historyIndex < commandHistory.length - 1) {
            historyIndex++;
            currentLine = commandHistory[historyIndex];
            term.write('\r\x1B[K' + prompt + currentLine);
        } else {
            historyIndex = commandHistory.length;
            currentLine = '';
            term.write('\r\x1B[K' + prompt);
        }
    } else if (printable) {
        currentLine += e.key;
        term.write(e.key);
    }
});

// Handle window resizing
window.addEventListener('resize', () => {
    fitAddon.fit();
});

// Optional: WebSocket connection setup (if server is available)
try {
    const ws = new WebSocket(`ws://localhost:3000`);
    
    ws.onopen = () => {
        term.writeln('WebSocket connection established');
    };

    ws.onmessage = (event) => {
        term.writeln(event.data);
    };

    ws.onerror = () => {
        term.writeln('WebSocket connection failed - falling back to offline mode');
    };

    ws.onclose = () => {
        term.writeln('WebSocket connection closed');
    };
} catch (error) {
    term.writeln('Operating in offline mode');
}
// <----------End of XTerm code------------>
// <----------Start of Cpu/Disk/Mem usage data pulling code------------>
async function fetchMetrics() {
    try {
        // Fetch data from the Go backend API (using dynamically updated IP)
        const response = await fetch('http://localhost:8080/metrics'); // The IP will be dynamically updated by the .sh script

        // If the response is not ok, throw an error
        if (!response.ok) {
            document.getElementById('Errors').textContent = "HTTP error, Status: ${response.status}";
        }

        // Parse the response JSON
        const data = await response.json();

        // Update the progress bars with the fetched data
        document.getElementById('cpuProgress').style.width = `${data.cpu}%`;
        document.getElementById('cpuText').textContent = `${data.cpu}%`;

        document.getElementById('memoryProgress').style.width = `${data.memory}%`;
        document.getElementById('memoryText').textContent = `${data.memory}%`;

        document.getElementById('diskProgress').style.width = `${data.disk}%`;
        document.getElementById('diskText').textContent = `${data.disk}%`;

    } catch (error) {
        console.error('Error fetching metrics:', error);
    }
}

// Fetch metrics every 3 seconds
setInterval(fetchMetrics, 3000);
// Fetch once when the page loads
fetchMetrics();
// <----------End of Cpu/Disk/Mem usage data pulling code------------>