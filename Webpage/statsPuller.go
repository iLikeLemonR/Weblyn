package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/disk"
	"github.com/shirou/gopsutil/mem"
)

// Middleware to handle CORS
func handleCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*") // Allow all domains
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST") // Allowed HTTP methods
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization") // Allowed headers
		if r.Method == http.MethodOptions { // Pre-flight request
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// Helper function to round a float to one decimal place
func roundToOneDecimalPlace(value float64) float64 {
	return math.Round(value*10) / 10
}

// Function to get system metrics (CPU, Memory, Disk)
func getMetrics(w http.ResponseWriter, r *http.Request) {
	// CPU usage
	cpuPercent, err := cpu.Percent(0, false)
	if err != nil {
		http.Error(w, "Error retrieving CPU usage", http.StatusInternalServerError)
		return
	}

	// Memory usage
	memStats, err := mem.VirtualMemory()
	if err != nil {
		http.Error(w, "Error retrieving memory usage", http.StatusInternalServerError)
		return
	}

	// Disk usage
	diskStats, err := disk.Usage("/")
	if err != nil {
		http.Error(w, "Error retrieving disk usage", http.StatusInternalServerError)
		return
	}

	// Create a structure to hold the data
	metrics := struct {
		CPU    float64 `json:"cpu"`
		Memory float64 `json:"memory"`
		Disk   float64 `json:"disk"`
	}{
		CPU:    roundToOneDecimalPlace(cpuPercent[0]),           // Get the first value from the CPU percentage array
		Memory: roundToOneDecimalPlace(memStats.UsedPercent),    // Get the percentage of memory used
		Disk:   roundToOneDecimalPlace(diskStats.UsedPercent),   // Get the percentage of disk space used
	}

	// Set the content type as JSON
	w.Header().Set("Content-Type", "application/json")
	// Write the response as JSON
	err = json.NewEncoder(w).Encode(metrics)
	if err != nil {
		http.Error(w, "Error encoding JSON response", http.StatusInternalServerError)
		return
	}
}

func main() {
	// Set up the server
	mux := http.NewServeMux()
	mux.HandleFunc("/metrics", getMetrics)

	// Wrap the mux with the CORS handler
	http.Handle("/", handleCORS(mux))

	// Start the server
	fmt.Println("Server started at http://localhost:8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal("Error starting server:", err)
	}
}
// another test comment