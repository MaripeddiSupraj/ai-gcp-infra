#!/bin/bash

# Concurrent User Load Test Script
# Tests session creation, pod startup, and UI loading for multiple users

set -e

# Configuration
API_ENDPOINT="http://34.46.174.78"
API_KEY="your-secure-api-key-change-in-production"
NUM_USERS=${1:-5}  # Default 5 users, can override with argument
TEST_PREFIX="loadtest-$(date +%s)"
RESULTS_DIR="/tmp/loadtest-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}🚀 CONCURRENT USER LOAD TEST${NC}"
echo "=================================="
echo "Users: $NUM_USERS"
echo "Start Time: $(date)"
echo "Results Dir: $RESULTS_DIR"
echo ""

# Function to test single user
test_user() {
    local user_id=$1
    local user_num=$2
    local result_file="$RESULTS_DIR/user$user_num.log"
    
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - Starting test" | tee "$result_file"
    
    # Step 1: Create session
    local session_start=$(date +%s.%3N)
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - Creating session..." | tee -a "$result_file"
    
    local response=$(curl -s -X POST "$API_ENDPOINT/session/create" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"user_id\": \"$user_id\"}")
    
    local session_end=$(date +%s.%3N)
    local session_time=$(echo "$session_end - $session_start" | bc)
    
    local uuid=$(echo "$response" | jq -r '.uuid')
    local workspace_url=$(echo "$response" | jq -r '.workspace_url')
    
    if [ "$uuid" = "null" ] || [ -z "$uuid" ]; then
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ❌ Session creation failed" | tee -a "$result_file"
        echo "$response" | tee -a "$result_file"
        return 1
    fi
    
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ✅ Session created: $uuid (${session_time}s)" | tee -a "$result_file"
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - URL: $workspace_url" | tee -a "$result_file"
    
    # Step 2: Wait for pod to be ready
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - Waiting for pod..." | tee -a "$result_file"
    local pod_start=$(date +%s.%3N)
    
    # Wait up to 180 seconds for pod to be ready
    local pod_ready=false
    for i in {1..60}; do
        if kubectl get pod -l uuid="$uuid" --no-headers 2>/dev/null | grep -q "Running"; then
            pod_ready=true
            break
        fi
        sleep 3
    done
    
    local pod_end=$(date +%s.%3N)
    local pod_time=$(echo "$pod_end - $pod_start" | bc)
    
    if [ "$pod_ready" = true ]; then
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ✅ Pod ready (${pod_time}s)" | tee -a "$result_file"
    else
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ❌ Pod timeout after ${pod_time}s" | tee -a "$result_file"
        return 1
    fi
    
    # Step 3: Test UI loading
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - Testing UI..." | tee -a "$result_file"
    local ui_start=$(date +%s.%3N)
    
    # Test UI with retries
    local ui_ready=false
    for i in {1..10}; do
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$workspace_url" || echo "000")
        if [ "$http_code" = "200" ] || [ "$http_code" = "302" ]; then
            ui_ready=true
            break
        fi
        sleep 2
    done
    
    local ui_end=$(date +%s.%3N)
    local ui_time=$(echo "$ui_end - $ui_start" | bc)
    local total_time=$(echo "$ui_end - $session_start" | bc)
    
    if [ "$ui_ready" = true ]; then
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ✅ UI ready (${ui_time}s)" | tee -a "$result_file"
    else
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ❌ UI timeout after ${ui_time}s" | tee -a "$result_file"
    fi
    
    # Step 4: Create test file for persistence test
    local pod_name=$(kubectl get pod -l uuid="$uuid" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$pod_name" ]; then
        kubectl exec "$pod_name" -- sh -c "echo 'Test file for user $user_num created at $(date)' > /app/test-user$user_num.txt" 2>/dev/null || true
        echo "$(date '+%H:%M:%S.%3N') - USER $user_num - ✅ Test file created" | tee -a "$result_file"
    fi
    
    # Summary
    echo "$(date '+%H:%M:%S.%3N') - USER $user_num - 🎯 TOTAL TIME: ${total_time}s" | tee -a "$result_file"
    echo "SESSION_TIME:$session_time,POD_TIME:$pod_time,UI_TIME:$ui_time,TOTAL_TIME:$total_time,UUID:$uuid" >> "$RESULTS_DIR/summary.csv"
    
    return 0
}

# Initialize summary file
echo "USER,SESSION_TIME,POD_TIME,UI_TIME,TOTAL_TIME,UUID" > "$RESULTS_DIR/summary.csv"

# Start concurrent tests
echo -e "${YELLOW}Starting $NUM_USERS concurrent tests...${NC}"
pids=()

for i in $(seq 1 $NUM_USERS); do
    user_id="$TEST_PREFIX-user$i@example.com"
    test_user "$user_id" "$i" &
    pids+=($!)
    sleep 0.5  # Small delay to avoid API rate limiting
done

# Wait for all tests to complete
echo -e "${YELLOW}Waiting for all tests to complete...${NC}"
for pid in "${pids[@]}"; do
    wait "$pid"
done

# Generate summary report
echo ""
echo -e "${GREEN}📊 TEST RESULTS SUMMARY${NC}"
echo "========================"

if [ -f "$RESULTS_DIR/summary.csv" ]; then
    echo "Results saved to: $RESULTS_DIR/summary.csv"
    echo ""
    
    # Calculate averages
    tail -n +2 "$RESULTS_DIR/summary.csv" | while IFS=',' read -r user session_time pod_time ui_time total_time uuid; do
        echo "User $user: Session=${session_time}s, Pod=${pod_time}s, UI=${ui_time}s, Total=${total_time}s"
    done
    
    echo ""
    echo "Average times:"
    awk -F',' 'NR>1 {session+=$2; pod+=$3; ui+=$4; total+=$5; count++} END {
        if(count>0) {
            printf "Session: %.2fs\n", session/count
            printf "Pod: %.2fs\n", pod/count  
            printf "UI: %.2fs\n", ui/count
            printf "Total: %.2fs\n", total/count
        }
    }' "$RESULTS_DIR/summary.csv"
fi

echo ""
echo -e "${BLUE}Test completed at: $(date)${NC}"
echo "Individual logs available in: $RESULTS_DIR/"