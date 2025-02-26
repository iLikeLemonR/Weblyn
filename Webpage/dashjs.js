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
// <----------Start of Terminal and Websocket code------------>

// <----------End of Terminal and Websocket code------------>
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