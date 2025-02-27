const express = require('express');
const cors = require('cors');
const si = require('systeminformation');

const app = express();
const PORT = 8080;

app.use(cors()); // Enable CORS for all routes
app.use(express.json());

// Helper function to round values to one decimal place
function roundToOneDecimalPlace(value) {
    return Math.round(value * 10) / 10;
}

// Function to fetch system metrics
async function getMetrics(req, res) {
    try {
        // CPU Usage (Real-Time per Core Average)
        const cpuLoad = await si.currentLoad();
        const cpuUsage = roundToOneDecimalPlace(cpuLoad.currentLoad);
        
        // Get total number of cores
        const cpuInfo = await si.cpu();
        const totalCores = cpuInfo.cores;

        // Memory Usage
        const memory = await si.mem();
        const memoryUsage = roundToOneDecimalPlace((memory.active / memory.total) * 100);

        // Disk Usage (All Disks Combined)
        const disks = await si.fsSize();
        let totalDiskSpace = 0;
        let totalUsedSpace = 0;

        disks.forEach(disk => {
            totalDiskSpace += disk.size; // Total disk size
            totalUsedSpace += disk.used; // Total used space
        });

        const diskUsage = roundToOneDecimalPlace((totalUsedSpace / totalDiskSpace) * 100);

        const metrics = {
            cpu: cpuUsage,
            memory: memoryUsage,
            disk: diskUsage,
            totalDiskSpace: roundToOneDecimalPlace(totalDiskSpace / (1024 ** 3)), // GB
            totalUsedSpace: roundToOneDecimalPlace(totalUsedSpace / (1024 ** 3)), // GB
            totalMemory: roundToOneDecimalPlace(memory.total / (1024 ** 3)), // GB
            totalUsedMemory: roundToOneDecimalPlace(memory.active / (1024 ** 3)), // GB
            cores: totalCores
        };

        res.json(metrics);
    } catch (error) {
        console.error("Error fetching system metrics:", error);
        res.status(500).json({ error: "Failed to retrieve metrics" });
    }
}

app.get('/metrics', getMetrics);

app.listen(PORT, () => {
    console.log(`Server started at http://localhost:${PORT}`);
});