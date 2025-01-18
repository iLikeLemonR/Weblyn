// <	Start of Theme Switching code	>
document.querySelectorAll('.dropdown-item[data-theme]').forEach(item => {
    item.addEventListener('click', (e) => {
        e.preventDefault();
        const theme = e.target.getAttribute('data-theme');
        document.body.classList.remove('dark-mode', 'light-mode', 'retro', 'solarized', "high-contrast", "pastel-dream");
        document.body.classList.add(theme);
        updateTerminalTheme(theme);
    });
});
// <	End of Theme Switching code	>
// <	Start of XTerm code	>
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
    },
    allowProposedApi: true,
    cursorStyle: 'block'
});
const fitAddon = new FitAddon.FitAddon();
term.loadAddon(fitAddon);
// Initialize terminal
term.open(document.getElementById('terminal-container'));
fitAddon.fit();

// Terminal state management
let commandHistory = [];
let historyIndex = -1;
let currentLine = '';
let cursorPosition = 0;
let currentPrompt = '';
let currentDirectory = '~';
let isTypingAllowed = true;

function refreshLine() {
    const fullLine = currentPrompt + currentLine;
    term.write('\r' + ' '.repeat(term.cols)); // Clear the line
    term.write('\r' + fullLine); // Rewrite the line
    // Move cursor to correct position
    const targetPosition = currentPrompt.length + cursorPosition;
    const currentPos = currentPrompt.length + currentLine.length;
    if (targetPosition < currentPos) {
        term.write('\x1b[' + (currentPos - targetPosition) + 'D');
    }
}

function clearCurrentLine() {
    const currentPos = currentPrompt.length + cursorPosition;
    term.write('\r' + ' '.repeat(term.cols));
    term.write('\r');
}

function writePrompt() {
    term.write('\r\n' + currentPrompt);
    currentLine = '';
    cursorPosition = 0;
    isTypingAllowed = true;
}

writePrompt();

// Theme Switching Functionality
document.addEventListener('DOMContentLoaded', () => {
    // Store the theme handlers in an object
    const themeHandlers = {
        'dark-mode': () => {
            document.body.className = 'dark-mode';
            updateTerminalTheme('dark-mode');
        },
        'light-mode': () => {
            document.body.className = 'light-mode';
            updateTerminalTheme('light-mode');
        },
        'retro': () => {
            document.body.className = 'retro';
            updateTerminalTheme('retro');
        },
        'solarized': () => {
            document.body.className = 'solarized';
            updateTerminalTheme('solarized');
        },
        'high-contrast': () => {
            document.body.className = 'high-contrast';
            // Add terminal theme for high contrast if needed
        },
        'pastel-dream': () => {
            document.body.className = 'pastel-dream';
            // Add terminal theme for pastel dream if needed
        }
    };
    // Add click handlers for each theme option
    const themeDropdownItems = document.querySelectorAll('.dropdown-item[data-theme]');
    themeDropdownItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const selectedTheme = e.target.getAttribute('data-theme');
            // Remove all existing theme classes
            document.body.classList.remove('dark-mode', 'light-mode', 'retro', 'solarized', 'high-contrast', 'pastel-dream');
            // Apply the selected theme
            if (themeHandlers[selectedTheme]) {
                themeHandlers[selectedTheme]();
            }
            // Store the selected theme in localStorage for persistence
            localStorage.setItem('preferred-theme', selectedTheme);
        });
    });
    // Load saved theme on page load
    const savedTheme = localStorage.getItem('preferred-theme');
    if (savedTheme && themeHandlers[savedTheme]) {
        themeHandlers[savedTheme]();
    }
});

// Update the terminal themes object to include all theme options
const terminalThemes = {
    'dark-mode': { 
        background: '#1e1e1e', 
        foreground: '#ffffff' 
    },
    'light-mode': { 
        background: '#f1f9e9', 
        foreground: '#000000' 
    },
    'retro': { 
        background: '#F6DCAC', 
        foreground: '#01204E' 
    },
    'solarized': { 
        background: '#073642', 
        foreground: '#839496' 
    },
    'high-contrast': { 
        background: '#333333', 
        foreground: '#ffffff' 
    },
    'pastel-dream': { 
        background: '#ffe4e1', 
        foreground: '#2f4f4f' 
    }
};

function updateTerminalTheme(themeName) {
    if (terminalThemes[themeName]) {
        term.setOption('theme', terminalThemes[themeName]);
    }
}

// WebSocket connection setup
try {
    const ws = new WebSocket(`ws://localhost:3000`);
    ws.onopen = () => {
        term.writeln('WebSocket connection established');
        writePrompt();
    };
    ws.onmessage = (event) => {
        term.writeln(event.data);
        const match = event.data.match(/(\w+)@(\w+):(.*)\$/);
        if (match) {
            currentDirectory = match[3];
            currentPrompt = `${match[1]}@${match[2]}:${currentDirectory}$ `;
        }
        writePrompt();
    };
    ws.onerror = () => {
        term.writeln('WebSocket connection failed - falling back to offline mode');
        writePrompt();
    };
    ws.onclose = () => {
        term.writeln('WebSocket connection closed');
        writePrompt();
    };
} catch (error) {
    term.writeln('Operating in offline mode');
    writePrompt();
}

// Handle terminal input
term.onKey((e) => {
    if (!isTypingAllowed) return;

    const ev = e.domEvent;
    const printable = !ev.altKey && !ev.ctrlKey && !ev.metaKey;

    // Handle Ctrl+V (paste)
    if (ev.ctrlKey && ev.code === 'KeyV') {
        navigator.clipboard.readText().then(text => {
            // Insert text at cursor position
            currentLine = currentLine.slice(0, cursorPosition) + text + currentLine.slice(cursorPosition);
            cursorPosition += text.length;
            refreshLine();
        });
        return;
    }

    // Handle Ctrl+C (cancel)
    if (ev.ctrlKey && ev.code === 'KeyC') {
        term.write('^C');
        currentLine = '';
        cursorPosition = 0;
        writePrompt();
        return;
    }

    switch (ev.keyCode) {
        case 13: // Enter
            isTypingAllowed = false;
            term.write('\r\n');
            const command = currentLine.trim();
            if (command) {
                commandHistory.push(command);
                historyIndex = commandHistory.length;
                ws.send(command); // Send only the command without the prefix
            }
            currentLine = '';
            cursorPosition = 0;
            break;
        case 8: // Backspace
            if (cursorPosition > 0) {
                currentLine = currentLine.slice(0, cursorPosition - 1) + currentLine.slice(cursorPosition);
                cursorPosition--;
                refreshLine();
            }
            break;
        case 46: // Delete
            if (cursorPosition < currentLine.length) {
                currentLine = currentLine.slice(0, cursorPosition) + currentLine.slice(cursorPosition + 1);
                refreshLine();
            }
            break;
        case 37: // Left arrow
            if (cursorPosition > 0) {
                cursorPosition--;
                refreshLine();
            }
            break;
        case 39: // Right arrow
            if (cursorPosition < currentLine.length) {
                cursorPosition++;
                refreshLine();
            }
            break;
        case 38: // Up arrow
            if (historyIndex > 0) {
                historyIndex--;
                currentLine = commandHistory[historyIndex];
                cursorPosition = currentLine.length;
                refreshLine();
            }
            break;
        case 40: // Down arrow
            if (historyIndex < commandHistory.length - 1) {
                historyIndex++;
                currentLine = commandHistory[historyIndex];
            } else {
                historyIndex = commandHistory.length;
                currentLine = '';
            }
            cursorPosition = currentLine.length;
            refreshLine();
            break;
        case 36: // Home
            cursorPosition = 0;
            refreshLine();
            break;
        case 35: // End
            cursorPosition = currentLine.length;
            refreshLine();
            break;
        default:
            if (printable && !ev.altKey && !ev.ctrlKey && !ev.metaKey) {
                currentLine = currentLine.slice(0, cursorPosition) + e.key + currentLine.slice(cursorPosition);
                cursorPosition++;
                refreshLine();
            }
    }
});

// Handle window resizing
window.addEventListener('resize', () => {
    fitAddon.fit();
});
// <	End of XTerm code	>
// <	Start of Cpu/Disk/Mem usage data pulling code	>
async function fetchMetrics() {
    try {
        // Fetch data from the Go backend API (using dynamically updated IP)
        const response = await fetch('http://localhost:8080/metrics'); // The IP will be dynamically updated by the .sh script
        // If the response is not ok, throw an error
        if (!response.ok) {
            document.getElementById('Errors').textContent = `HTTP error, Status: ${response.status}`;
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
// <	End of Cpu/Disk/Mem usage data pulling code	>