document.addEventListener('DOMContentLoaded', () => {
    // Create particle elements for the background
    const bgAnimation = document.querySelector('.bg-animation');
    for (let i = 0; i < 50; i++) {
        const particle = document.createElement('div');
        particle.className = 'particle';
        particle.style.left = `${Math.random() * 100}%`;
        particle.style.top = `${Math.random() * 100}%`;
        particle.style.animationDelay = `${Math.random() * 15}s`;
        bgAnimation.appendChild(particle);
    }
    
    // Update live clock
    function updateClock() {
        const now = new Date();
        document.getElementById('hours').textContent = String(Math.abs(now.getHours() - 12)).padStart(2, '0');
        document.getElementById('minutes').textContent = String(now.getMinutes()).padStart(2, '0');
        document.getElementById('seconds').textContent = String(now.getSeconds()).padStart(2, '0');
        if (now.getHours() > 12){
            document.getElementById('pm/am').textContent = " PM";
        } else {
            document.getElementById('pm/am').textContent = " AM";
        }
        
        // Update card classes based on values (demo)
        updateCardColors();
    }

    // Track previous metrics for trend detection
    let previousCpuValue = null;
    let previousMemValue = null;
    let previousDiskValue = null;
    let cpuDifference = 0;
    let memDifference = 0;
    let diskDifference = 0;
    
    async function fetchMetrics() {
        try {
            // Fetch data from the NodeJS backend API
            const response = await fetch('http://localhost:8080/metrics');
    
            // If the response is not ok, throw an error
            if (!response.ok) {
                document.getElementById('Errors').textContent = `HTTP error, Status: ${response.status}`;
                return;
            }
    
            // Parse the response JSON
            const data = await response.json();
    
            // Calculate metrics' trends and differences
            const currentCpuValue = data.cpu;
            const currentMemValue = data.memory;
            const currentDiskValue = data.disk;
            
            if (previousCpuValue !== null) {
                cpuDifference = parseFloat((currentCpuValue - previousCpuValue).toFixed(1));
            }
            if (previousMemValue !== null) {
                memDifference = parseFloat((currentMemValue - previousMemValue).toFixed(1));
            }
            if (previousDiskValue !== null) {
                diskDifference = parseFloat((currentDiskValue - previousDiskValue).toFixed(1));
            }
            
            // Save current value for next comparison
            previousCpuValue = currentCpuValue;
            previousMemValue = currentMemValue;
            previousDiskValue = currentDiskValue;
            
            // Update the UI with the fetched data
            document.getElementById('coresTotal').textContent = `${data.cores} Cores`;
            document.getElementById('cpuText').textContent = `${data.cpu}%`;

            document.getElementById('memTotal').textContent = `${data.totalUsedMemory}GB / ${data.totalMemory}GB (Free: ${Math.round((data.totalMemory - data.totalUsedMemory) * 10) / 10}GB)`;
            document.getElementById('memText').textContent = `${data.memory}%`;

            document.getElementById('diskTotal').textContent = `${data.totalUsedSpace}GB / ${data.totalDiskSpace}GB (Free: ${Math.round((data.totalDiskSpace - data.totalUsedSpace) * 10) / 10}GB)`;
            document.getElementById('diskText').textContent = `${data.disk}%`;

            // Update card colors based on the new data
            updateCardColors();
    
        } catch (error) {
            console.error('Error fetching metrics:', error);
        }
    }
    // Fetch metrics every 1 second
    fetchMetrics();
    setInterval(fetchMetrics, 1000);
    
    function updateCardColors() {
        const cpuValue = parseInt(document.querySelector('#cpu-card .stat-value').textContent);
        const memValue = parseInt(document.querySelector('#memory-card .stat-value').textContent);
        const diskValue = parseInt(document.querySelector('#disk-card .stat-value').textContent);

        const cpuCard = document.getElementById('cpu-card');
        const memCard = document.getElementById('memory-card');
        const diskCard = document.getElementById('disk-card');

        const cpuStatArrow = document.getElementById('cpu-card-stat-change');
        const memStatArrow = document.getElementById('mem-card-stat-change');
        const diskStatArrow = document.getElementById('disk-card-stat-change');
        
        // Reset classes
        cpuCard.classList.remove('high-usage', 'medium-usage', 'low-usage');
        memCard.classList.remove('high-usage', 'medium-usage', 'low-usage');
        diskCard.classList.remove('high-usage', 'medium-usage', 'low-usage');
        
        // Apply classes based on values
        if (cpuValue > 70) cpuCard.classList.add('high-usage');
        else if (cpuValue > 40) cpuCard.classList.add('medium-usage');
        else cpuCard.classList.add('low-usage');
        
        if (memValue > 70) memCard.classList.add('high-usage');
        else if (memValue > 40) memCard.classList.add('medium-usage');
        else memCard.classList.add('low-usage');
        
        if (diskValue > 70) diskCard.classList.add('high-usage');
        else if (diskValue > 40) diskCard.classList.add('medium-usage');
        else diskCard.classList.add('low-usage');

        // Update state change arrows
        if (cpuStatArrow) {
            if (cpuDifference > 0) {
                cpuStatArrow.classList.remove('down-arrow', 'decrease');
                cpuStatArrow.classList.add('up-arrow', 'increase');
                cpuStatArrow.textContent = `+${cpuDifference}%`;
            } else if (cpuDifference < 0) {
                cpuStatArrow.classList.remove('up-arrow', 'increase');
                cpuStatArrow.classList.add('down-arrow', 'decrease');
                cpuStatArrow.textContent = `${cpuDifference}%`;
            } else {
                cpuStatArrow.classList.remove('up-arrow', 'down-arrow', 'increase', 'decrease');
                cpuStatArrow.textContent = `${cpuDifference}%`;
            }
        }
        if (memStatArrow) {
            if (memDifference > 0) {
                memStatArrow.classList.remove('down-arrow', 'decrease');
                memStatArrow.classList.add('up-arrow', 'increase');
                memStatArrow.textContent = `+${memDifference}%`;
            } else if (memDifference < 0) {
                memStatArrow.classList.remove('up-arrow', 'increase');
                memStatArrow.classList.add('down-arrow', 'decrease');
                memStatArrow.textContent = `${memDifference}%`;
            } else {
                memStatArrow.classList.remove('up-arrow', 'down-arrow', 'increase', 'decrease');
                memStatArrow.textContent = `${memDifference}%`;
            }
        }
        if (diskStatArrow) {
            if (diskDifference > 0) {
                diskStatArrow.classList.remove('down-arrow', 'decrease');
                diskStatArrow.classList.add('up-arrow', 'increase');
                diskStatArrow.textContent = `+${diskDifference}%`;
            } else if (diskDifference < 0) {
                diskStatArrow.classList.remove('up-arrow', 'increase');
                diskStatArrow.classList.add('down-arrow', 'decrease');
                diskStatArrow.textContent = `${diskDifference}%`;
            } else {
                diskStatArrow.classList.remove('up-arrow', 'down-arrow', 'increase', 'decrease');
                diskStatArrow.textContent = `${diskDifference}%`;
            }
        }
    }
    // Update clock every 1 second
    updateClock();
    setInterval(updateClock, 1000);
    
    // Custom cursor functionality
    const cursor = document.querySelector('.cursor');
    const body = document.querySelector('body');
    
    // Create trail elements
    const trailCount = 12; // Number of trail elements
    const trails = [];
    
    for (let i = 0; i < trailCount; i++) {
        const trail = document.createElement('div');
        trail.className = 'cursor-trail';
        body.appendChild(trail);
        trails.push({
            element: trail,
            x: 0,
            y: 0,
            alpha: 0.5 - (i * 0.4 / trailCount),  // Decreasing opacity for trail elements
            size: 16 - (i * 16 / trailCount)     // Decreasing size for trail elements
        });
    }
    
    // Variables to store current and previous mouse positions
    let currentX = 0;
    let currentY = 0;
    let mouseX = 0;
    let mouseY = 0;
    
    // Update mouse position on mouse move
    document.addEventListener('mousemove', (e) => {
        mouseX = e.clientX;
        mouseY = e.clientY;
        
        // Check if cursor is over any interactive elements
        const hoveredElement = document.elementFromPoint(mouseX, mouseY);
        if (hoveredElement && (
            hoveredElement.tagName === 'A' || 
            hoveredElement.tagName === 'BUTTON' || 
            hoveredElement.classList.contains('stat-card') ||
            hoveredElement.classList.contains('ref-link')
        )) {
            cursor.style.width = '40px';
            cursor.style.height = '40px';
            cursor.style.backgroundColor = 'rgba(255, 255, 255, 0.8)';
            cursor.style.filter = 'drop-shadow(0 0 15px rgba(255, 255, 255, 0.8))';
        } else {
            cursor.style.width = '20px';
            cursor.style.height = '20px';
            cursor.style.backgroundColor = 'rgba(100, 150, 255, 0.8)';
            cursor.style.filter = 'drop-shadow(0 0 12px rgba(100, 150, 255, 0.6))';
        }
    });
    
    // Make sure cursor is hidden when mouse leaves the window
    document.addEventListener('mouseout', () => {
        cursor.style.opacity = '0';
        trails.forEach(trail => {
            trail.element.style.opacity = '0';
        });
    });
    
    // Show cursor when mouse enters the window
    document.addEventListener('mouseover', () => {
        cursor.style.opacity = '1';
        trails.forEach(trail => {
            trail.element.style.opacity = '1';
        });
    });
    
    // Smooth cursor animation
    function animateCursor() {
        // Smooth lerp (linear interpolation) for main cursor
        const ease = 0.2; // Adjust for more or less smoothness (0.1 to 0.3 works well)
        
        currentX += (mouseX - currentX) * ease;
        currentY += (mouseY - currentY) * ease;
        
        // Update main cursor position
        cursor.style.left = `${currentX}px`;
        cursor.style.top = `${currentY}px`;
        
        // Update trail positions with delay
        trails.forEach((trail, index) => {
            // Add delay to each trail element
            setTimeout(() => {
                // Previous trail position or current mouse position
                const prevTrail = trails[index - 1] || { x: currentX, y: currentY };
                
                trail.x += (prevTrail.x - trail.x) * (ease - 0.05);
                trail.y += (prevTrail.y - trail.y) * (ease - 0.05);
                
                // Update trail element position and appearance
                trail.element.style.left = `${trail.x}px`;
                trail.element.style.top = `${trail.y}px`;
                trail.element.style.width = `${trail.size}px`;
                trail.element.style.height = `${trail.size}px`;
                trail.element.style.backgroundColor = `rgba(100, 150, 255, ${trail.alpha})`;
            }, index * 5); // Staggered delay for smooth trail effect
        });
        
        requestAnimationFrame(animateCursor);
    }
    
    animateCursor();
});