const express = require('express');
const cors = require('cors');
const si = require('systeminformation');
const rateLimit = require('express-rate-limit');

const app = express();
const PORT = process.env.PORT || 8080;

// Configure rate limiting
const limiter = rateLimit({
    windowMs: 1 * 60 * 1000, // 1 minute
    max: 60, // limit each IP to 60 requests per windowMs
    message: 'Too many requests from this IP, please try again later'
});

// Middleware
app.use(cors());
app.use(express.json());
app.use('/metrics', limiter);

// Helper function to round values to one decimal place
function roundToOneDecimalPlace(value) {
    return Math.round(value * 10) / 10;
}

// Helper function to convert bytes to GB
function bytesToGB(bytes) {
    return roundToOneDecimalPlace(bytes / (1024 ** 3));
}

// Function to fetch system metrics
async function getMetrics(req, res) {
    try {
        // Fetch all metrics in parallel for better performance
        const [cpuLoad, cpuInfo, memory, disks] = await Promise.all([
            si.currentLoad(),
            si.cpu(),
            si.mem(),
            si.fsSize()
        ]);

        // Calculate CPU metrics
        const cpuUsage = roundToOneDecimalPlace(cpuLoad.currentLoad);
        const totalCores = cpuInfo.cores;

        // Calculate memory metrics
        const memoryUsage = roundToOneDecimalPlace((memory.active / memory.total) * 100);
        const totalMemoryGB = bytesToGB(memory.total);
        const usedMemoryGB = bytesToGB(memory.active);

        // Calculate disk metrics
        let totalDiskSpace = 0;
        let totalUsedSpace = 0;

        disks.forEach(disk => {
            totalDiskSpace += disk.size;
            totalUsedSpace += disk.used;
        });

        const diskUsage = roundToOneDecimalPlace((totalUsedSpace / totalDiskSpace) * 100);
        const totalDiskSpaceGB = bytesToGB(totalDiskSpace);
        const totalUsedSpaceGB = bytesToGB(totalUsedSpace);

        // Prepare response object
        const metrics = {
            cpu: {
                usage: cpuUsage,
                cores: totalCores
            },
            memory: {
                usage: memoryUsage,
                total: totalMemoryGB,
                used: usedMemoryGB
            },
            disk: {
                usage: diskUsage,
                total: totalDiskSpaceGB,
                used: totalUsedSpaceGB
            },
            timestamp: new Date().toISOString()
        };

        res.json(metrics);
    } catch (error) {
        console.error("Error fetching system metrics:", error);
        res.status(500).json({
            error: "Failed to retrieve metrics",
            message: process.env.NODE_ENV === 'development' ? error.message : 'Internal server error'
        });
    }
}

// Routes
app.get('/metrics', getMetrics);

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: "Internal server error",
        message: process.env.NODE_ENV === 'development' ? err.message : 'Something went wrong'
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server started at http://localhost:${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});