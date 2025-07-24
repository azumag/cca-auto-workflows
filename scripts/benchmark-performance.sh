#!/bin/bash

# Performance Benchmarking Script for Claude Code Auto Workflows
# This script runs comprehensive benchmarks to validate optimization improvements

set -euo pipefail

# Source modular libraries
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
source "$script_dir/lib/github-api.sh"
source "$script_dir/lib/workflow-analyzer.sh"
source "$script_dir/lib/performance-metrics.sh"
source "$script_dir/lib/report-generator.sh"

# Benchmark configuration
BENCHMARK_ITERATIONS="${BENCHMARK_ITERATIONS:-10}"
BENCHMARK_OUTPUT_DIR="${TMPDIR:-/tmp}/performance-benchmarks"
BENCHMARK_REPORT_FILE="$BENCHMARK_OUTPUT_DIR/benchmark-report-$(date +%Y%m%d-%H%M%S).json"

# Benchmark scenarios
SCENARIO_LIGHT_LOAD=10    # Light API load simulation
SCENARIO_MEDIUM_LOAD=25   # Medium API load simulation
SCENARIO_HEAVY_LOAD=50    # Heavy API load simulation

# Performance baselines (in seconds)
BASELINE_CACHE_OPERATION=0.001
BASELINE_API_CALL=0.1
BASELINE_WORKFLOW_ANALYSIS=0.5
BASELINE_REPORT_GENERATION=0.2

# Initialize benchmarking
benchmark_init() {
    log_info "🚀 Initializing performance benchmarking system..."
    
    setup_cache "$BENCHMARK_OUTPUT_DIR"
    performance_metrics_init
    github_api_init
    
    # Reset all metrics
    github_api_reset_metrics
    
    log_info "✅ Benchmark environment initialized"
    log_info "📊 Benchmark iterations: $BENCHMARK_ITERATIONS"
    log_info "📁 Output directory: $BENCHMARK_OUTPUT_DIR"
}

# Benchmark cache operations
benchmark_cache_operations() {
    log_header "🏃 Benchmarking cache operations..."
    
    local cache_dir="$BENCHMARK_OUTPUT_DIR/cache_bench"
    setup_cache "$cache_dir"
    
    # Benchmark cache write operations
    log_info "Testing cache write performance..."
    run_performance_benchmark "cache_write" "
        test_key='benchmark_write_\$(date +%s%N)'
        test_data='Benchmark data for cache write test with some content to make it realistic'
        save_to_cache \"\$test_key\" \"\$test_data\" '$cache_dir'
    "
    
    # Benchmark cache read operations
    log_info "Testing cache read performance..."
    local test_key="persistent_read_key"
    save_to_cache "$test_key" "Persistent test data for read benchmarking" "$cache_dir"
    
    run_performance_benchmark "cache_read" "
        get_from_cache '$test_key' '$cache_dir' 300 >/dev/null
    "
    
    # Benchmark cache key generation
    log_info "Testing cache key generation performance..."
    run_performance_benchmark "cache_key_generation" "
        get_cache_key 'test input data for key generation benchmark \$(date +%s%N)' >/dev/null
    "
    
    # Benchmark cache validation
    log_info "Testing cache validation performance..."
    local validation_file="$cache_dir/validation_test"
    echo "validation data" > "$validation_file"
    
    run_performance_benchmark "cache_validation" "
        is_cache_valid '$validation_file' 300
    "
    
    cleanup_cache "$cache_dir" 0
}

# Benchmark GitHub API operations
benchmark_github_api() {
    log_header "🌐 Benchmarking GitHub API operations..."
    
    # Mock GitHub CLI for consistent benchmarking
    create_benchmark_gh_mock
    
    # Benchmark rate limit checking
    log_info "Testing rate limit check performance..."
    run_performance_benchmark "api_rate_limit_check" "
        github_get_rate_limit >/dev/null
    "
    
    # Benchmark API call with caching
    log_info "Testing cached API call performance..."
    run_performance_benchmark "api_call_cached" "
        github_api_call 'test/endpoint' >/dev/null
    "
    
    # Benchmark workflow run listing
    log_info "Testing workflow run list performance..."
    run_performance_benchmark "workflow_run_list" "
        github_run_list '--limit 20' >/dev/null
    "
    
    # Benchmark cache hit scenario
    log_info "Testing API cache hit performance..."
    # Prime the cache
    github_api_call "cached/endpoint" >/dev/null
    
    run_performance_benchmark "api_cache_hit" "
        github_api_call 'cached/endpoint' >/dev/null
    "
}

# Benchmark workflow analysis
benchmark_workflow_analysis() {
    log_header "📊 Benchmarking workflow analysis operations..."
    
    # Create test workflow directory
    local test_workflows_dir="$BENCHMARK_OUTPUT_DIR/test_workflows"
    create_benchmark_workflows "$test_workflows_dir"
    
    # Change to test directory for analysis
    local original_dir="$PWD"
    cd "$BENCHMARK_OUTPUT_DIR"
    
    # Initialize workflow analyzer
    workflow_analyzer_init >/dev/null
    
    # Benchmark workflow runtime analysis
    log_info "Testing workflow runtime analysis performance..."
    run_performance_benchmark "workflow_runtime_analysis" "
        analyze_workflow_runtime >/dev/null
    "
    
    # Benchmark workflow efficiency analysis
    log_info "Testing workflow efficiency analysis performance..."
    run_performance_benchmark "workflow_efficiency_analysis" "
        analyze_workflow_efficiency >/dev/null
    "
    
    # Benchmark workflow complexity analysis
    log_info "Testing workflow complexity analysis performance..."
    run_performance_benchmark "workflow_complexity_analysis" "
        analyze_workflow_complexity >/dev/null
    "
    
    cd "$original_dir"
}

# Benchmark report generation
benchmark_report_generation() {
    log_header "📄 Benchmarking report generation operations..."
    
    report_generator_init >/dev/null
    
    # Benchmark API usage report
    log_info "Testing API usage report generation performance..."
    run_performance_benchmark "api_usage_report" "
        generate_api_usage_report >/dev/null
    "
    
    # Benchmark workflow optimization report
    log_info "Testing workflow optimization report performance..."
    run_performance_benchmark "workflow_optimization_report" "
        generate_workflow_optimization_report >/dev/null
    "
    
    # Benchmark JSON report generation
    log_info "Testing JSON report generation performance..."
    run_performance_benchmark "json_report_generation" "
        local temp_json='/tmp/benchmark_report_\$(date +%s%N).json'
        generate_json_report \"\$temp_json\" >/dev/null
        rm -f \"\$temp_json\"
    "
    
    # Benchmark Markdown report generation
    log_info "Testing Markdown report generation performance..."
    run_performance_benchmark "markdown_report_generation" "
        local temp_md='/tmp/benchmark_report_\$(date +%s%N).md'
        generate_comprehensive_report \"\$temp_md\" >/dev/null
        rm -f \"\$temp_md\"
    "
}

# Benchmark load scenarios
benchmark_load_scenarios() {
    log_header "🔥 Benchmarking under different load scenarios..."
    
    # Light load scenario
    log_info "Testing light load scenario ($SCENARIO_LIGHT_LOAD operations)..."
    run_load_test "light_load_scenario" "
        github_get_rate_limit >/dev/null
    " 2 "$SCENARIO_LIGHT_LOAD"
    
    # Medium load scenario
    log_info "Testing medium load scenario ($SCENARIO_MEDIUM_LOAD operations)..."
    run_load_test "medium_load_scenario" "
        github_api_call 'load/test' >/dev/null
    " 5 "$SCENARIO_MEDIUM_LOAD"
    
    # Heavy load scenario
    log_info "Testing heavy load scenario ($SCENARIO_HEAVY_LOAD operations)..."
    run_load_test "heavy_load_scenario" "
        # Mix of operations
        if [ \$((RANDOM % 3)) -eq 0 ]; then
            github_get_rate_limit >/dev/null
        elif [ \$((RANDOM % 2)) -eq 0 ]; then
            github_api_call 'heavy/test' >/dev/null
        else
            github_run_list '--limit 5' >/dev/null
        fi
    " 10 "$SCENARIO_HEAVY_LOAD"
}

# Benchmark memory usage
benchmark_memory_usage() {
    log_header "💾 Benchmarking memory usage patterns..."
    
    # Function to get memory usage
    get_memory_usage() {
        local pid="$1"
        ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ' || echo "0"
    }
    
    # Benchmark large cache operations
    log_info "Testing memory usage with large cache operations..."
    local large_cache_dir="$BENCHMARK_OUTPUT_DIR/large_cache"
    setup_cache "$large_cache_dir"
    
    # Create large data for caching
    local large_data
    large_data=$(yes "Large data for memory benchmark testing" | head -n 1000 | tr '\n' ' ')
    
    # Monitor memory during large cache operations
    local initial_memory baseline_memory final_memory
    initial_memory=$(get_memory_usage $$)
    
    # Perform memory-intensive operations
    for i in {1..50}; do
        save_to_cache "large_key_$i" "$large_data" "$large_cache_dir"
    done
    
    baseline_memory=$(get_memory_usage $$)
    
    # Read all cached data
    for i in {1..50}; do
        get_from_cache "large_key_$i" "$large_cache_dir" 300 >/dev/null
    done
    
    final_memory=$(get_memory_usage $$)
    
    log_info "💾 Memory Usage Analysis:"
    log_info "  📊 Initial memory: ${initial_memory}KB"
    log_info "  📊 After caching: ${baseline_memory}KB"
    log_info "  📊 After reading: ${final_memory}KB"
    log_info "  📊 Memory delta: $((final_memory - initial_memory))KB"
    
    cleanup_cache "$large_cache_dir" 0
}

# Analyze benchmark results
analyze_benchmark_results() {
    log_header "📈 Analyzing benchmark results..."
    
    # Generate comprehensive performance report
    generate_performance_report
    
    # Get metrics from all components
    local api_metrics workflow_metrics
    api_metrics=$(github_api_get_metrics)
    workflow_metrics=$(workflow_analyzer_get_metrics)
    
    log_info "🔍 Benchmark Analysis Summary:"
    
    # API performance analysis
    local api_calls cache_hits hit_rate
    api_calls=$(echo "$api_metrics" | jq -r '.api_calls_total')
    cache_hits=$(echo "$api_metrics" | jq -r '.cache_hits')
    hit_rate=$(echo "$api_metrics" | jq -r '.cache_hit_rate_percent')
    
    log_info "  🌐 API Performance:"
    log_info "    📞 Total API calls: $api_calls"
    log_info "    💾 Cache hits: $cache_hits ($hit_rate%)"
    
    # Workflow analysis performance
    local workflows_analyzed issues_found
    workflows_analyzed=$(echo "$workflow_metrics" | jq -r '.workflows_analyzed')
    issues_found=$(echo "$workflow_metrics" | jq -r '.performance_issues_found')
    
    log_info "  📊 Workflow Analysis:"
    log_info "    🔍 Workflows analyzed: $workflows_analyzed"
    log_info "    ⚠️  Issues identified: $issues_found"
    
    # Performance comparison with baselines
    log_info "  📏 Performance vs Baselines:"
    
    local cache_avg api_avg workflow_avg report_avg
    cache_avg=$(get_average_operation_time "cache_read")
    api_avg=$(get_average_operation_time "api_rate_limit_check")
    workflow_avg=$(get_average_operation_time "workflow_runtime_analysis")
    report_avg=$(get_average_operation_time "json_report_generation")
    
    # Compare with baselines (simplified comparison)
    local cache_performance api_performance workflow_performance report_performance
    cache_performance=$(echo "scale=1; $cache_avg / $BASELINE_CACHE_OPERATION" | bc -l 2>/dev/null || echo "1.0")
    api_performance=$(echo "scale=1; $api_avg / $BASELINE_API_CALL" | bc -l 2>/dev/null || echo "1.0")
    workflow_performance=$(echo "scale=1; $workflow_avg / $BASELINE_WORKFLOW_ANALYSIS" | bc -l 2>/dev/null || echo "1.0")
    report_performance=$(echo "scale=1; $report_avg / $BASELINE_REPORT_GENERATION" | bc -l 2>/dev/null || echo "1.0")
    
    log_info "    💾 Cache ops: ${cache_avg}s (${cache_performance}x baseline)"
    log_info "    🌐 API calls: ${api_avg}s (${api_performance}x baseline)"
    log_info "    📊 Workflow analysis: ${workflow_avg}s (${workflow_performance}x baseline)"
    log_info "    📄 Report generation: ${report_avg}s (${report_performance}x baseline)"
}

# Generate benchmark report
generate_benchmark_report() {
    log_header "📊 Generating comprehensive benchmark report..."
    
    # Create detailed JSON report
    cat > "$BENCHMARK_REPORT_FILE" << EOF
{
  "benchmark_report": {
    "generated_at": "$(date -Iseconds)",
    "benchmark_iterations": $BENCHMARK_ITERATIONS,
    "environment": {
      "hostname": "$(hostname)",
      "os": "$(uname -s)",
      "architecture": "$(uname -m)",
      "shell": "$SHELL",
      "benchmark_version": "1.0.0"
    },
    "performance_metrics": $(github_api_get_metrics),
    "workflow_metrics": $(workflow_analyzer_get_metrics),
    "baselines": {
      "cache_operation": $BASELINE_CACHE_OPERATION,
      "api_call": $BASELINE_API_CALL,
      "workflow_analysis": $BASELINE_WORKFLOW_ANALYSIS,
      "report_generation": $BASELINE_REPORT_GENERATION
    },
    "test_scenarios": {
      "light_load": $SCENARIO_LIGHT_LOAD,
      "medium_load": $SCENARIO_MEDIUM_LOAD,
      "heavy_load": $SCENARIO_HEAVY_LOAD
    }
  }
}
EOF
    
    # Export performance metrics
    local metrics_file="${BENCHMARK_REPORT_FILE%.json}-detailed-metrics.json"
    export_metrics_json "$metrics_file"
    
    log_info "📄 Benchmark report saved to: $BENCHMARK_REPORT_FILE"
    log_info "📊 Detailed metrics saved to: $metrics_file"
    
    # Generate summary
    log_info "📋 Benchmark Summary:"
    log_info "  ⏱️  Total benchmark time: $(echo "$(date +%s.%N) - $SCRIPT_START_TIME" | bc -l 2>/dev/null || echo "N/A")s"
    log_info "  🔄 Iterations completed: $BENCHMARK_ITERATIONS"
    log_info "  📁 Reports generated: 2"
    log_info "  ✅ Benchmark status: COMPLETED"
}

# Create benchmark GitHub CLI mock
create_benchmark_gh_mock() {
    cat > "$TEST_TEMP_DIR/bin/gh" << 'EOF'
#!/bin/bash
# High-performance GitHub CLI mock for benchmarking
case "$1 $2" in
    "auth status")
        exit 0
        ;;
    "api rate_limit")
        echo '{"rate":{"limit":5000,"used":1000,"remaining":4000,"reset":1640995200}}'
        exit 0
        ;;
    "run list"*)
        echo '[{"name":"Benchmark","status":"completed","conclusion":"success","createdAt":"2024-01-01T00:00:00Z","updatedAt":"2024-01-01T00:05:00Z","databaseId":1}]'
        exit 0
        ;;
    "api "*"/workflows" | "api "*"/test" | "api "*"/endpoint" | "api "*"/cached" | "api "*"/load" | "api "*"/heavy")
        echo '{"benchmark": "response", "timestamp": "'$(date -Iseconds)'"}'
        exit 0
        ;;
    *)
        echo '{"mock": "response"}'
        exit 0
        ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/gh"
    
    # Also create jq mock for consistent JSON processing
    cat > "$TEST_TEMP_DIR/bin/jq" << 'EOF'
#!/bin/bash
case "$*" in
    "-r" ".rate.used") echo "1000" ;;
    "-r" ".rate.limit") echo "5000" ;;
    "-r" ".rate.remaining") echo "4000" ;;
    "-r" ".rate.reset") echo "1640995200" ;;
    *) echo "1" ;;
esac
EOF
    chmod +x "$TEST_TEMP_DIR/bin/jq"
}

# Create test workflows for benchmarking
create_benchmark_workflows() {
    local workflows_dir="$1/.github/workflows"
    mkdir -p "$workflows_dir"
    
    # Create multiple workflow files for testing
    for i in {1..5}; do
        cat > "$workflows_dir/benchmark-workflow-$i.yml" << EOF
name: Benchmark Workflow $i
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: \${{ runner.os }}-node-\${{ hashFiles('package-lock.json') }}
      - name: Test step $i
        run: echo "Testing workflow $i"
        if: github.event_name == 'push'
EOF
    done
}

# Main benchmarking function
main() {
    log_info "🏁 Starting comprehensive performance benchmarking..."
    
    # Initialize benchmarking system
    benchmark_init
    
    echo
    
    # Run all benchmark suites
    benchmark_cache_operations
    echo
    
    benchmark_github_api
    echo
    
    benchmark_workflow_analysis
    echo
    
    benchmark_report_generation
    echo
    
    benchmark_load_scenarios
    echo
    
    benchmark_memory_usage
    echo
    
    # Analyze results
    analyze_benchmark_results
    echo
    
    # Generate final report
    generate_benchmark_report
    echo
    
    # Cleanup
    performance_metrics_cleanup
    github_api_cleanup
    workflow_analyzer_cleanup
    report_generator_cleanup
    
    log_info "🎉 Performance benchmarking completed successfully!"
    log_info "📊 Review the benchmark report for detailed performance analysis."
}

# Set up error handling
trap 'log_error "Benchmark failed on line $LINENO"; exit 1' ERR

# Execute main function
main "$@"