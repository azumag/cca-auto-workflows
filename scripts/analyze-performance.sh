#!/bin/bash

# Performance Analysis Script for Claude Code Auto Workflows
# This script analyzes workflow performance and provides optimization suggestions
# Refactored to use modular architecture with single responsibility principle

set -euo pipefail

# Source modular libraries
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Load configuration
load_config "${CONFIG_FILE:-}"

# Setup signal handling
setup_signal_handling

# Source other modular libraries
source "$script_dir/lib/github-api.sh"
source "$script_dir/lib/workflow-analyzer.sh"
source "$script_dir/lib/performance-metrics.sh"
source "$script_dir/lib/report-generator.sh"

# Override log_header for this script's specific purpose
log_header() {
    echo -e "${BLUE}[ANALYSIS]${NC} $*"
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Performance Analysis Script for Claude Code Auto Workflows

OPTIONS:
    --benchmarks        Enable performance benchmarking
    --load-tests        Enable load testing
    --format FORMAT     Output format: console, json, markdown (default: console)
    --output FILE       Save output to file
    --help              Show this help message

EXAMPLES:
    $0                                    # Basic analysis
    $0 --benchmarks                       # Include benchmarks
    $0 --format json --output report.json # Generate JSON report
    $0 --load-tests --benchmarks          # Full performance testing

ENVIRONMENT VARIABLES:
    ENABLE_BENCHMARKS   Set to 'true' to enable benchmarking
    ENABLE_LOAD_TESTS   Set to 'true' to enable load testing
    OUTPUT_FORMAT       Default output format
    OUTPUT_FILE         Default output file
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --benchmarks)
                ENABLE_BENCHMARKS="true"
                shift
                ;;
            --load-tests)
                ENABLE_LOAD_TESTS="true"
                shift
                ;;
            --format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate output format
    case "$OUTPUT_FORMAT" in
        console|json|markdown) ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
}

# Initialize all modules
initialize_modules() {
    log_info "🚀 Initializing performance analysis modules..."
    
    start_timer "module_initialization"
    
    # Initialize modules in order
    if ! github_api_init; then
        log_error "Failed to initialize GitHub API module"
        return 1
    fi
    
    if ! workflow_analyzer_init; then
        log_error "Failed to initialize workflow analyzer"
        return 1
    fi
    
    if ! performance_metrics_init; then
        log_error "Failed to initialize performance metrics"
        return 1
    fi
    
    if ! report_generator_init; then
        log_error "Failed to initialize report generator"
        return 1
    fi
    
    end_timer "module_initialization" "true"
    log_info "✅ All modules initialized successfully"
}

# Run performance benchmarks
run_benchmarks() {
    if [[ "$ENABLE_BENCHMARKS" != "true" ]]; then
        return 0
    fi
    
    log_header "Running performance benchmarks..."
    
    # Benchmark API operations
    run_performance_benchmark "github_api_rate_limit" "github_get_rate_limit >/dev/null"
    
    # Benchmark workflow analysis
    run_performance_benchmark "workflow_runtime_analysis" "analyze_workflow_runtime >/dev/null"
    
    # Benchmark caching operations - use safe static values
    run_performance_benchmark "cache_operations" "
        test_key='benchmark_test_static'
        test_data='sample data for benchmarking'
        benchmark_cache_dir='/tmp/benchmark_cache_$$'
        setup_cache \"\$benchmark_cache_dir\"
        save_to_cache \"\$test_key\" \"\$test_data\" \"\$benchmark_cache_dir\"
        get_from_cache \"\$test_key\" \"\$benchmark_cache_dir\" 300 >/dev/null
        rm -rf \"\$benchmark_cache_dir\"
    "
}

# Run load tests
run_load_tests() {
    if [[ "$ENABLE_LOAD_TESTS" != "true" ]]; then
        return 0
    fi
    
    log_header "Running load tests..."
    
    # Test API rate limiting under load
    run_load_test "api_rate_limit_load" "github_get_rate_limit >/dev/null" 5 20
    
    # Test cache performance under concurrent access - use safe values
    run_load_test "cache_concurrent_access" "
        test_key='load_test_static'
        test_data='load test data'
        load_cache_dir='/tmp/load_test_cache_$$'
        setup_cache \"\$load_cache_dir\" 2>/dev/null || true
        save_to_cache \"\$test_key\" \"\$test_data\" \"\$load_cache_dir\"
        get_from_cache \"\$test_key\" \"\$load_cache_dir\" 300 >/dev/null
    " 10 50
}

# Generate and output final report
generate_final_report() {
    case "$OUTPUT_FORMAT" in
        console)
            log_info "📊 Generating console performance report..."
            
            # Generate comprehensive performance report
            generate_performance_report
            echo
            
            # Generate API usage report
            generate_api_usage_report >/dev/null
            echo
            
            # Generate workflow optimization recommendations
            generate_workflow_optimization_report
            echo
            
            # Show module statistics
            github_api_show_stats
            ;;
            
        json)
            local json_file
            if [[ -n "$OUTPUT_FILE" ]]; then
                json_file="$OUTPUT_FILE"
            else
                json_file="performance-report-$(date +%Y%m%d-%H%M%S).json"
            fi
            
            log_info "📊 Generating JSON report: $json_file"
            generate_json_report "$json_file"
            
            # Also export performance metrics
            local metrics_file="${json_file%.json}-metrics.json"
            export_metrics_json "$metrics_file"
            ;;
            
        markdown)
            local md_file
            if [[ -n "$OUTPUT_FILE" ]]; then
                md_file="$OUTPUT_FILE"
            else
                md_file="performance-report-$(date +%Y%m%d-%H%M%S).md"
            fi
            
            log_info "📄 Generating Markdown report: $md_file"
            generate_comprehensive_report "$md_file"
            ;;
    esac
}

# Cleanup function for graceful shutdown
cleanup_performance_analysis() {
    log_info "🧹 Cleaning up performance analysis resources..."
    
    # Clean up any temporary files including benchmark and load test caches
    rm -f /tmp/performance_analysis_$$.* 2>/dev/null || true
    rm -rf /tmp/benchmark_cache_$$ 2>/dev/null || true
    rm -rf /tmp/load_test_cache_$$ 2>/dev/null || true
    
    # Cleanup modules if they exist
    if declare -F performance_metrics_cleanup > /dev/null; then
        performance_metrics_cleanup
    fi
    
    if declare -F workflow_analyzer_cleanup > /dev/null; then
        workflow_analyzer_cleanup
    fi
    
    if declare -F github_api_cleanup > /dev/null; then
        github_api_cleanup
    fi
    
    if declare -F report_generator_cleanup > /dev/null; then
        report_generator_cleanup
    fi
}

# Cleanup all modules
cleanup_modules() {
    log_info "🧹 Cleaning up modules..."
    
    start_timer "module_cleanup"
    
    if declare -F performance_metrics_cleanup > /dev/null; then
        performance_metrics_cleanup
    fi
    
    if declare -F workflow_analyzer_cleanup > /dev/null; then
        workflow_analyzer_cleanup
    fi
    
    if declare -F github_api_cleanup > /dev/null; then
        github_api_cleanup
    fi
    
    if declare -F report_generator_cleanup > /dev/null; then
        report_generator_cleanup
    fi
    
    end_timer "module_cleanup" "true"
    log_info "✅ Module cleanup completed"
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    log_info "📊 Starting performance analysis for Claude Code Auto Workflows..."
    log_info "🔧 Configuration: benchmarks=$ENABLE_BENCHMARKS, load-tests=$ENABLE_LOAD_TESTS, format=$OUTPUT_FORMAT"
    
    # Register cleanup function for graceful shutdown
    add_cleanup_function cleanup_performance_analysis
    
    # Initialize all modules
    if ! initialize_modules; then
        log_error "❌ Module initialization failed"
        exit 1
    fi
    
    echo
    
    # Run core analysis
    start_timer "workflow_runtime_analysis"
    analyze_workflow_runtime
    end_timer "workflow_runtime_analysis" "true"
    echo
    
    start_timer "api_usage_analysis"  
    generate_api_usage_report >/dev/null
    end_timer "api_usage_analysis" "true"
    echo
    
    start_timer "workflow_efficiency_analysis"
    analyze_workflow_efficiency
    end_timer "workflow_efficiency_analysis" "true"
    echo
    
    # Run workflow complexity analysis
    start_timer "workflow_complexity_analysis"
    analyze_workflow_complexity
    end_timer "workflow_complexity_analysis" "true"
    echo
    
    # Run optional performance tests
    run_benchmarks
    run_load_tests
    
    # Generate final report
    start_timer "report_generation"
    generate_final_report
    end_timer "report_generation" "true"
    echo
    
    # Show final performance metrics
    generate_performance_report
    echo
    
    # Cleanup
    cleanup_modules
    
    log_info "🎉 Performance analysis completed successfully!"
    log_info "   📈 Use the recommendations above to optimize your workflow performance."
}

# Set up error handling
trap 'log_error "Script failed on line $LINENO"; cleanup_modules; exit 1' ERR

# Execute main function
main "$@"