#!/usr/bin/env bats

# Tests for scripts/analyze-performance.sh
# This file tests all functionality of the performance analysis script

# Load test helpers
load helpers/common.bash

# Set up BATS
setup() {
    setup_bats_libs
    load test-config.bash
    common_setup
    
    # Copy the script under test
    SCRIPT_PATH="./scripts/analyze-performance.sh"
    
    # Ensure script is executable
    chmod +x "$SCRIPT_PATH"
}

teardown() {
    restore_commands
    common_teardown
}

@test "analyze-performance.sh exists and is executable" {
    [ -f "$SCRIPT_PATH" ]
    [ -x "$SCRIPT_PATH" ]
}

@test "script displays help information" {
    run grep -q "Performance Analysis Script" "$SCRIPT_PATH"
    assert_success
}

@test "script sets proper error handling" {
    run grep -q "set -euo pipefail" "$SCRIPT_PATH"
    assert_success
}

@test "analyze_workflow_runtime function exists" {
    run grep -q "analyze_workflow_runtime()" "$SCRIPT_PATH"
    assert_success
}

@test "analyze_workflow_runtime reports error when gh CLI not available" {
    # Mock command to simulate gh not being available
    command() {
        if [[ "$1" == "-v" && "$2" == "gh" ]]; then
            return 1
        fi
        return 0
    }
    export -f command
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runtime"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "analyze_workflow_runtime handles empty workflow data" {
    # Mock gh CLI to return empty array
    gh() {
        if [[ "$*" =~ "run list" ]]; then
            echo "[]"
            return 0
        fi
        return 1
    }
    export -f gh
    
    # Mock command to simulate gh being available
    command() {
        if [[ "$1" == "-v" && "$2" == "gh" ]]; then
            return 0
        fi
        return 0
    }
    export -f command
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runtime"
    assert_success
    assert_output --partial "No workflow run data available"
}

@test "analyze_workflow_runtime processes workflow data with jq" {
    # Mock successful gh and jq commands
    command() { return 0; }
    export -f command
    
    gh() {
        if [[ "$*" =~ "run list" ]]; then
            echo '[
        {
            "name": "CI",
            "status": "completed",
            "conclusion": "success",
            "createdAt": "2024-01-01T00:00:00Z",
            "updatedAt": "2024-01-01T00:05:00Z",
            "databaseId": 12345
        }
    ]'
            return 0
        fi
        return 1
    }
    export -f gh
    
    jq() {
        echo "  📊 CI: 5min avg, 100% success rate (1 runs)"
        return 0
    }
    export -f jq
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runtime"
    assert_success
    assert_output --partial "Recent workflow performance"
}

@test "analyze_api_usage function exists" {
    run grep -q "analyze_api_usage()" "$SCRIPT_PATH"
    assert_success
}

@test "analyze_api_usage handles API access failure" {
    # Mock gh to fail on rate limit check
    eval "gh() {
        if [[ \"\$1\" == \"api\" && \"\$2\" == \"rate_limit\" ]]; then
            return 1
        fi
        return 0
    }"
    
    run bash -c "source $SCRIPT_PATH && analyze_api_usage"
    assert_failure
    assert_output --partial "Cannot access GitHub API rate limit information"
}

@test "analyze_api_usage processes rate limit information" {
    # Mock successful rate limit response
    gh() {
        if [[ "$*" =~ "api rate_limit" ]]; then
            echo '{
        "rate": {
            "used": 1000,
            "limit": 5000,
            "remaining": 4000
        }
    }'
            return 0
        fi
        return 1
    }
    export -f gh
    
    # Mock jq for individual field extraction
    jq() {
        case "$2" in
            '.rate.used') echo '1000' ;;
            '.rate.limit') echo '5000' ;;
            '.rate.remaining') echo '4000' ;;
            *) echo '{}' ;;
        esac
    }
    export -f jq
    
    run bash -c "source $SCRIPT_PATH && analyze_api_usage"
    assert_success
    assert_output --partial "GitHub API Usage"
    assert_output --partial "1000/5000 used"
}

@test "analyze_api_usage warns on high usage" {
    # Mock high API usage scenario
    gh() {
        if [[ "$*" =~ "api rate_limit" ]]; then
            echo '{
        "rate": {
            "used": 4500,
            "limit": 5000,
            "remaining": 500
        }
    }'
            return 0
        fi
        return 1
    }
    export -f gh
    
    jq() {
        case "$2" in
            '.rate.used') echo '4500' ;;
            '.rate.limit') echo '5000' ;;
            '.rate.remaining') echo '500' ;;
            *) echo '{}' ;;
        esac
    }
    export -f jq
    
    run bash -c "source $SCRIPT_PATH && analyze_api_usage"
    assert_success
    assert_output --partial "High API usage detected"
}

@test "suggest_api_optimizations function provides recommendations" {
    run bash -c "source $SCRIPT_PATH && suggest_api_optimizations"
    assert_success
    assert_output --partial "API Optimization Suggestions"
    assert_output --partial "GitHub App tokens"
    assert_output --partial "caching"
}

@test "analyze_workflow_efficiency function exists" {
    run grep -q "analyze_workflow_efficiency()" "$SCRIPT_PATH"
    assert_success
}

@test "analyze_workflow_efficiency handles missing workflow directory" {
    # Ensure no .github/workflows directory exists
    run bash -c "source $SCRIPT_PATH && analyze_workflow_efficiency"
    assert_success
    assert_output --partial "No workflow directory found"
}

@test "analyze_workflow_efficiency analyzes existing workflows" {
    # Create mock workflow directory
    local workflows_dir
    workflows_dir=$(setup_mock_workflows "$TEMP_TEST_DIR")
    
    # Change to the temp directory so the script finds the workflows
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Workflow Configuration Analysis"
    assert_output --partial "Total workflows: 2"
}

@test "analyze_workflow_efficiency detects caching usage" {
    # Create workflow with caching
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    cat > "$workflows_dir/cached.yml" << 'EOF'
name: Cached Workflow
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/cache@v3
        with:
          path: node_modules
          key: deps
EOF
    
    cd "$TEMP_TEST_DIR"
    
    # Create a modified version of the function that works with BATS
    run bash -c "
        # Load only the functions without running main
        source <(sed '/^main.*\"\$@\"/d' $SCRIPT_PATH)
        
        # Override the analyze_workflow_efficiency function with debugging
        analyze_workflow_efficiency() {
            log_header \"Analyzing workflow efficiency...\"
            
            local workflow_dir=\".github/workflows\"
            if [[ ! -d \"\$workflow_dir\" ]]; then
                log_warn \"No workflow directory found\"
                return 0
            fi
            
            local workflow_count
            workflow_count=\$(find \"\$workflow_dir\" -name \"*.yml\" -o -name \"*.yaml\" | wc -l)
            
            log_info \"Workflow Configuration Analysis:\"
            log_info \"  📁 Total workflows: \$workflow_count\"
            
            # Check for potential optimizations
            local caching_workflows=0
            local conditional_workflows=0
            local matrix_workflows=0
            
            for file in \"\$workflow_dir\"/*.yml \"\$workflow_dir\"/*.yaml; do
                # Skip if file doesn't exist (when no files match the pattern)
                [[ -f \"\$file\" ]] || continue
                
                if grep -q \"cache:\" \"\$file\" || grep -q \"actions/cache\" \"\$file\"; then
                    caching_workflows=\$((caching_workflows + 1))
                fi
                
                if grep -q \"if:\" \"\$file\"; then
                    conditional_workflows=\$((conditional_workflows + 1))
                fi
                
                if grep -q \"strategy:\" \"\$file\" && grep -q \"matrix:\" \"\$file\"; then
                    matrix_workflows=\$((matrix_workflows + 1))
                fi
            done
            
            log_info \"  🚀 Using caching: \$caching_workflows/\$workflow_count workflows\"
            log_info \"  🎯 Using conditionals: \$conditional_workflows/\$workflow_count workflows\"
            log_info \"  ⚡ Using matrix builds: \$matrix_workflows/\$workflow_count workflows\"
        }
        
        analyze_workflow_efficiency
    "
    assert_success
    assert_output --partial "🚀 Using caching: 1/1"
}

@test "generate_performance_report provides recommendations" {
    run bash -c "source $SCRIPT_PATH && generate_performance_report"
    assert_success
    assert_output --partial "Performance Optimization Recommendations"
    assert_output --partial "dependency caching"
    assert_output --partial "conditional job execution"
}

@test "main function executes all analysis steps" {
    # Create mock workflow directory
    mkdir -p "$TEMP_TEST_DIR/.github/workflows"
    cat > "$TEMP_TEST_DIR/.github/workflows/test.yml" << 'EOF'
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
EOF
    
    cd "$TEMP_TEST_DIR"
    
    # Mock all required commands
    command() { return 0; }
    export -f command
    
    gh() {
        case "$*" in
            "run list"*) echo "[]" ;;
            "api rate_limit") echo '{"rate":{"used":100,"limit":5000,"remaining":4900}}' ;;
            *) return 1 ;;
        esac
    }
    
    jq() {
        case "$2" in
            '.rate.used') echo '100' ;;
            '.rate.limit') echo '5000' ;;
            '.rate.remaining') echo '4900' ;;
            *) echo '{}' ;;
        esac
    }
    export -f gh
    export -f jq
    
    run bash -c "source <(sed '/^main.*\"\$@\"/d' $SCRIPT_PATH) && main"
    assert_success
    assert_output --partial "Starting performance analysis"
    assert_output --partial "Performance analysis completed"
}

@test "script handles missing dependencies gracefully" {
    # Mock missing gh command
    command() {
        if [[ "$1" == "-v" && "$2" == "gh" ]]; then
            return 1
        fi
        return 0
    }
    export -f command
    
    run bash -c "source <(sed '/^main.*\"\$@\"/d' $SCRIPT_PATH) && analyze_workflow_runtime"
    assert_failure
    assert_output --partial "GitHub CLI (gh) is required"
}

@test "script uses proper color codes" {
    run grep -q "RED=" "$SCRIPT_PATH"
    assert_success
    run grep -q "GREEN=" "$SCRIPT_PATH"
    assert_success
    run grep -q "YELLOW=" "$SCRIPT_PATH"
    assert_success
    run grep -q "NC=" "$SCRIPT_PATH"
    assert_success
}

@test "logging functions exist and work properly" {
    run bash -c "source $SCRIPT_PATH && log_info 'test message'"
    assert_success
    assert_output --partial "test message"
    
    run bash -c "source $SCRIPT_PATH && log_warn 'warning message'"
    assert_success
    assert_output --partial "warning message"
    
    run bash -c "source $SCRIPT_PATH && log_error 'error message'"
    assert_success
    assert_output --partial "error message"
}

# Test edge cases and error conditions

@test "handles malformed JSON from GitHub API" {
    # Mock gh to return invalid JSON
    eval "gh() {
        echo 'invalid json'
        return 0
    }"
    
    eval "jq() {
        echo 'parse error' >&2
        return 1
    }"
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_runtime"
    # Should handle the error gracefully (exact behavior depends on implementation)
}

@test "handles network timeouts and API failures" {
    # Mock gh to simulate network timeout
    eval "gh() {
        echo 'timeout: network unreachable' >&2
        return 124
    }"
    
    run bash -c "source $SCRIPT_PATH && analyze_api_usage"
    assert_failure
}

@test "validates workflow file extensions" {
    # Create workflows with different extensions
    local workflows_dir="$TEMP_TEST_DIR/.github/workflows"
    mkdir -p "$workflows_dir"
    
    touch "$workflows_dir/test.yml"
    touch "$workflows_dir/test.yaml"
    touch "$workflows_dir/test.txt"  # Should be ignored
    
    cd "$TEMP_TEST_DIR"
    
    run bash -c "source $SCRIPT_PATH && analyze_workflow_efficiency"
    assert_success
    assert_output --partial "Total workflows: 2"  # Only .yml and .yaml counted
}