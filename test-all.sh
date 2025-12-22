#!/bin/bash

################################################################################
# COMPREHENSIVE AI-GCP-INFRA TEST SUITE
# All-in-one testing script combining all test scenarios
################################################################################

set -e

# Configuration
API_ENDPOINT="${API_ENDPOINT:-http://34.46.174.78}"
API_KEY="${API_KEY:-your-secure-api-key-change-in-production}"
NAMESPACE="${NAMESPACE:-default}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}\n"
}

print_test() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_TESTS++))
    ((TOTAL_TESTS++))
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Usage
show_usage() {
    cat << EOF
Usage: $0 [MODE] [OPTIONS]

MODES:
  health          - Health check and system status
  full            - Complete test suite (default)
  quick           - Quick API test
  persistence     - Persistence and sleep/wake tests
  concurrent N    - Concurrent load test with N users (default: 5)
  cleanup         - Cleanup old test sessions

OPTIONS:
  -e, --endpoint URL    API endpoint (default: http://34.46.174.78)
  -k, --key KEY         API key
  -n, --namespace NS    Kubernetes namespace (default: default)
  -h, --help           Show this help

EXAMPLES:
  $0 health                      # Run health check
  $0 full                        # Run all tests
  $0 concurrent 10               # Test with 10 concurrent users
  $0 persistence                 # Test persistence only

EOF
    exit 0
}

################################################################################
# TEST 1: HEALTH CHECK
################################################################################
test_health() {
    print_header "🏥 HEALTH CHECK"
    
    print_test "Checking API health..."
    response=$(curl -s "$API_ENDPOINT/health" || echo '{"error": "connection failed"}')
    
    if echo "$response" | jq -e '.status == "healthy"' > /dev/null 2>&1; then
        version=$(echo "$response" | jq -r '.version')
        redis=$(echo "$response" | jq -r '.redis')
        print_success "API is healthy - Version: $version, Redis: $redis"
    else
        print_error "API health check failed"
        echo "$response"
        return 1
    fi
    
    print_test "Checking Kubernetes components..."
    if kubectl get deployment session-manager -n "$NAMESPACE" &>/dev/null; then
        replicas=$(kubectl get deployment session-manager -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        print_success "Session Manager: $replicas replicas ready"
    else
        print_error "Session Manager deployment not found"
    fi
    
    if kubectl get deployment redis -n "$NAMESPACE" &>/dev/null; then
        print_success "Redis deployment found"
    else
        print_error "Redis deployment not found"
    fi
}

################################################################################
# TEST 2: SESSION LIFECYCLE
################################################################################
test_session_lifecycle() {
    print_header "🔄 SESSION LIFECYCLE TEST"
    
    local user_id="test-lifecycle-$(date +%s)@example.com"
    local session_uuid=""
    
    # Step 1: Create Session
    print_test "Creating session for $user_id..."
    local start_time=$(date +%s.%3N)
    
    response=$(curl -s -X POST "$API_ENDPOINT/session/create" \
        -H "X-API-Key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"user_id\": \"$user_id\"}")
    
    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    session_uuid=$(echo "$response" | jq -r '.uuid')
    workspace_url=$(echo "$response" | jq -r '.workspace_url')
    
    if [ "$session_uuid" != "null" ] && [ -n "$session_uuid" ]; then
        print_success "Session created: $session_uuid (${duration}s)"
        print_info "Workspace URL: $workspace_url"
    else
        print_error "Failed to create session"
        echo "$response"
        return 1
    fi
    
    # Step 2: Wait for Pod Ready
    print_test "Waiting for pod to be ready..."
    local pod_ready=false
    for i in {1..60}; do
        if kubectl get pod -l uuid="$session_uuid" -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "Running"; then
            pod_ready=true
            break
        fi
        sleep 3
    done
    
    if [ "$pod_ready" = true ]; then
        print_success "Pod is running"
    else
        print_error "Pod failed to start within 3 minutes"
        return 1
    fi
    
    # Step 3: Check Status
    print_test "Checking session status..."
    status_response=$(curl -s "$API_ENDPOINT/session/$session_uuid/status" \
        -H "X-API-Key: $API_KEY")
    
    replicas=$(echo "$status_response" | jq -r '.replicas')
    if [ "$replicas" = "1" ]; then
        print_success "Session status confirmed - Replicas: $replicas"
    else
        print_error "Unexpected replica count: $replicas"
    fi
    
    # Step 4: Create Test File in Pod
    print_test "Creating test file in persistent storage..."
    pod_name=$(kubectl get pod -l uuid="$session_uuid" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    
    if kubectl exec "$pod_name" -n "$NAMESPACE" -- sh -c "echo 'Persistence test $(date)' > /app/test-data.txt" 2>/dev/null; then
        print_success "Test file created in /app"
    else
        print_error "Failed to create test file"
    fi
    
    # Step 5: Sleep Pod
    print_test "Testing sleep functionality..."
    curl -s -X POST "$API_ENDPOINT/session/$session_uuid/sleep" \
        -H "X-API-Key: $API_KEY" > /dev/null
    
    sleep 15
    
    replicas=$(curl -s "$API_ENDPOINT/session/$session_uuid/status" -H "X-API-Key: $API_KEY" | jq -r '.replicas')
    if [ "$replicas" = "0" ]; then
        print_success "Pod successfully scaled to 0 (sleeping)"
    else
        print_error "Pod failed to sleep - Replicas: $replicas"
    fi
    
    # Step 6: Wake Pod
    print_test "Testing wake functionality..."
    curl -s -X POST "$API_ENDPOINT/session/$session_uuid/wake" \
        -H "X-API-Key: $API_KEY" > /dev/null
    
    sleep 45
    
    replicas=$(curl -s "$API_ENDPOINT/session/$session_uuid/status" -H "X-API-Key: $API_KEY" | jq -r '.replicas')
    if [ "$replicas" = "1" ]; then
        print_success "Pod successfully woken up"
    else
        print_error "Pod failed to wake - Replicas: $replicas"
    fi
    
    # Step 7: Verify Data Persistence
    print_test "Verifying data persistence after wake..."
    pod_name=$(kubectl get pod -l uuid="$session_uuid" -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    
    sleep 10  # Wait for pod to be fully ready
    
    if kubectl exec "$pod_name" -n "$NAMESPACE" -- cat /app/test-data.txt 2>/dev/null | grep -q "Persistence test"; then
        print_success "Data persisted across sleep/wake cycle!"
    else
        print_error "Data lost after wake"
    fi
    
    # Step 8: Delete Session
    print_test "Deleting session..."
    delete_response=$(curl -s -X DELETE "$API_ENDPOINT/session/$session_uuid" \
        -H "X-API-Key: $API_KEY")
    
    if echo "$delete_response" | jq -e '.status == "terminated"' > /dev/null 2>&1; then
        print_success "Session deleted successfully"
    else
        print_error "Failed to delete session"
    fi
    
    print_info "Lifecycle test complete for session: $session_uuid"
}

################################################################################
# TEST 3: CONCURRENT USERS
################################################################################
test_concurrent_users() {
    local num_users=${1:-5}
    print_header "👥 CONCURRENT USERS TEST ($num_users users)"
    
    local results_dir="/tmp/concurrent-test-$(date +%s)"
    mkdir -p "$results_dir"
    
    echo "USER,SESSION_TIME,POD_TIME,TOTAL_TIME,UUID" > "$results_dir/results.csv"
    
    test_single_user() {
        local user_num=$1
        local user_id="concurrent-test-$user_num-$(date +%s)@example.com"
        local log_file="$results_dir/user$user_num.log"
        
        local total_start=$(date +%s.%3N)
        
        # Create session
        local session_start=$(date +%s.%3N)
        response=$(curl -s -X POST "$API_ENDPOINT/session/create" \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"$user_id\"}")
        
        local session_end=$(date +%s.%3N)
        local session_time=$(echo "$session_end - $session_start" | bc)
        
        uuid=$(echo "$response" | jq -r '.uuid')
        echo "User $user_num - Session: $uuid (${session_time}s)" >> "$log_file"
        
        # Wait for pod
        local pod_start=$(date +%s.%3N)
        for i in {1..60}; do
            if kubectl get pod -l uuid="$uuid" -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q "Running"; then
                break
            fi
            sleep 3
        done
        local pod_end=$(date +%s.%3N)
        local pod_time=$(echo "$pod_end - $pod_start" | bc)
        
        local total_end=$(date +%s.%3N)
        local total_time=$(echo "$total_end - $total_start" | bc)
        
        echo "$user_num,$session_time,$pod_time,$total_time,$uuid" >> "$results_dir/results.csv"
        echo "User $user_num - Complete: ${total_time}s" >> "$log_file"
    }
    
    # Launch concurrent tests
    pids=()
    for i in $(seq 1 $num_users); do
        test_single_user "$i" &
        pids+=($!)
        sleep 0.5
    done
    
    print_info "Waiting for all $num_users tests to complete..."
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Calculate and display results
    if [ -f "$results_dir/results.csv" ]; then
        print_success "All concurrent tests completed"
        
        echo -e "\n${PURPLE}📊 Results Summary:${NC}"
        awk -F',' 'NR>1 {
            session+=$2; pod+=$3; total+=$4; count++
        } END {
            if(count>0) {
                printf "Average Session Time: %.2fs\n", session/count
                printf "Average Pod Time: %.2fs\n", pod/count
                printf "Average Total Time: %.2fs\n", total/count
            }
        }' "$results_dir/results.csv"
        
        print_info "Detailed results: $results_dir/results.csv"
    fi
}

################################################################################
# TEST 4: CLEANUP OLD SESSIONS
################################################################################
test_cleanup() {
    print_header "🧹 CLEANUP OLD TEST SESSIONS"
    
    print_test "Finding old test sessions..."
    sessions=$(curl -s "$API_ENDPOINT/sessions" -H "X-API-Key: $API_KEY" 2>/dev/null || echo '{}')
    
    # Clean up test session pods
    test_pods=$(kubectl get pods -n "$NAMESPACE" -l app --no-headers 2>/dev/null | grep -E "test|concurrent|loadtest" | awk '{print $1}' || true)
    
    if [ -z "$test_pods" ]; then
        print_info "No test sessions found"
    else
        count=0
        while IFS= read -r pod; do
            uuid=$(echo "$pod" | grep -oP 'user-\K[a-z0-9]+' || true)
            if [ -n "$uuid" ]; then
                print_test "Deleting session: $uuid"
                curl -s -X DELETE "$API_ENDPOINT/session/$uuid" -H "X-API-Key: $API_KEY" > /dev/null 2>&1 || true
                ((count++))
            fi
        done <<< "$test_pods"
        
        print_success "Cleaned up $count test sessions"
    fi
}

################################################################################
# MAIN EXECUTION
################################################################################

# Parse arguments
MODE="full"
while [[ $# -gt 0 ]]; do
    case $1 in
        health|quick|full|persistence|cleanup)
            MODE=$1
            shift
            ;;
        concurrent)
            MODE="concurrent"
            NUM_USERS=${2:-5}
            shift 2
            ;;
        -e|--endpoint)
            API_ENDPOINT="$2"
            shift 2
            ;;
        -k|--key)
            API_KEY="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# Display configuration
print_header "⚙️  CONFIGURATION"
echo "API Endpoint: $API_ENDPOINT"
echo "Namespace: $NAMESPACE"
echo "Mode: $MODE"
echo ""

# Run tests based on mode
case $MODE in
    health)
        test_health
        ;;
    quick)
        test_health
        print_header "🚀 QUICK API TEST"
        user_id="quick-test-$(date +%s)@example.com"
        response=$(curl -s -X POST "$API_ENDPOINT/session/create" \
            -H "X-API-Key: $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"user_id\": \"$user_id\"}")
        uuid=$(echo "$response" | jq -r '.uuid')
        if [ "$uuid" != "null" ]; then
            print_success "Quick test passed - Session: $uuid"
            print_info "Cleaning up..."
            curl -s -X DELETE "$API_ENDPOINT/session/$uuid" -H "X-API-Key: $API_KEY" > /dev/null
        else
            print_error "Quick test failed"
        fi
        ;;
    persistence)
        test_health
        test_session_lifecycle
        ;;
    concurrent)
        test_health
        test_concurrent_users "$NUM_USERS"
        ;;
    cleanup)
        test_cleanup
        ;;
    full)
        test_health
        test_session_lifecycle
        test_concurrent_users 3
        ;;
    *)
        echo "Unknown mode: $MODE"
        show_usage
        ;;
esac

# Final summary
print_header "📋 TEST SUMMARY"
echo "Total Tests: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}\n"
    exit 0
else
    echo -e "\n${RED}⚠️  SOME TESTS FAILED${NC}\n"
    exit 1
fi
