#!/bin/bash

# Troubleshooting Feedback Collection Tool
# This script provides an easy-to-use interface for collecting user feedback
# on troubleshooting time estimates and success rates

set -euo pipefail

# Get script directory and source dependencies
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
source "$script_dir/lib/troubleshooting-feedback.sh"

# Configuration
CONFIG_FILE="${CONFIG_FILE:-}"

# Usage information
show_usage() {
    cat << 'EOF'
📝 Troubleshooting Feedback Collection Tool

USAGE:
    ./troubleshooting-feedback.sh <command> [options]

COMMANDS:
    start <step_id> [description]  Start tracking a troubleshooting session
    end <session_id> [outcome]     End a session (outcome: success|failure)
    list-steps                     Show available troubleshooting steps
    list-active                    Show currently active sessions  
    report [format] [step] [days]  Generate feedback analytics report
    interactive                    Interactive troubleshooting session
    cleanup                        Clean up old feedback data

EXAMPLES:
    # Start tracking a configuration fix
    ./troubleshooting-feedback.sh start range_fix "Fixing MAX_PARALLEL_JOBS validation error"
    
    # End the session successfully  
    ./troubleshooting-feedback.sh end troubleshooting_range_fix_1647890123 success
    
    # Generate a report for the last 30 days
    ./troubleshooting-feedback.sh report console "*" 30
    
    # Interactive session (recommended for new users)
    ./troubleshooting-feedback.sh interactive

STEP IDs (examples):
    range_fix              Configuration value range errors (2-5 min)
    auth_failure          GitHub authentication issues (10-20 min)  
    claude_response       Claude Code not responding (10-25 min)
    cache_check           Cache-related problems (8-20 min)
    
    Use 'list-steps' to see all available step IDs and estimates.

OUTPUT FORMATS:
    console               Human-readable report (default)
    json                  Machine-readable JSON format

TIPS:
    - Use descriptive descriptions to help improve documentation
    - End sessions promptly for accurate timing
    - Provide feedback when prompted to help improve estimates
    - Use interactive mode if you're new to the tool

For more information, see docs/TROUBLESHOOTING.md
EOF
}

# Interactive troubleshooting session
run_interactive_session() {
    log_header "🔍 Interactive Troubleshooting Session"
    
    echo "This tool helps collect feedback on troubleshooting time estimates."
    echo "Your feedback helps improve the documentation for everyone!"
    echo
    
    # Show available steps
    echo "Available troubleshooting steps:"
    list_troubleshooting_steps | head -10
    echo "  ... (use 'list-steps' to see all available steps)"
    echo
    
    # Get step from user
    local step_id
    while true; do
        read -p "Enter the troubleshooting step ID you're working on: " step_id
        if [[ -n "${TROUBLESHOOTING_STEPS[$step_id]:-}" ]]; then
            break
        else
            echo "❌ Unknown step ID: $step_id"
            echo "Use 'list-steps' command to see available step IDs"
            read -p "Try again? (y/n) [y]: " continue_choice
            continue_choice=${continue_choice:-y}
            if [[ "$continue_choice" != "y" ]]; then
                log_info "👋 Exiting interactive session"
                return 0
            fi
        fi
    done
    
    # Get description
    local description
    read -p "Briefly describe what you're troubleshooting (optional): " description
    description=${description:-"Interactive troubleshooting session"}
    
    # Start the session
    local session_id
    session_id=$(start_troubleshooting_session "$step_id" "$description")
    
    echo
    log_info "⏰ Session started! Work on your troubleshooting task now."
    log_info "   Estimated time: ${TROUBLESHOOTING_STEPS[$step_id]}"
    echo
    
    # Wait for user to complete the task
    echo "Press ENTER when you've completed (or given up on) the troubleshooting task..."
    read -r
    
    # Get outcome
    local outcome
    while true; do
        read -p "Was the troubleshooting successful? (success/failure) [success]: " outcome
        outcome=${outcome:-success}
        if [[ "$outcome" == "success" || "$outcome" == "failure" ]]; then
            break
        fi
        echo "Please enter 'success' or 'failure'"
    done
    
    # Get additional notes
    local notes
    read -p "Any additional notes about the troubleshooting process? (optional): " notes
    
    # End the session
    end_troubleshooting_session "$session_id" "$outcome" "$notes"
    
    echo
    log_info "🎉 Thank you for contributing feedback to improve our troubleshooting documentation!"
}

# Main function
main() {
    # Load configuration
    load_config "$CONFIG_FILE"
    
    # Initialize feedback system
    troubleshooting_feedback_init
    
    # Parse command line arguments
    local command="${1:-}"
    
    case "$command" in
        "start")
            local step_id="${2:-}"
            local description="${3:-No description provided}"
            
            if [[ -z "$step_id" ]]; then
                log_error "Step ID is required"
                echo "Usage: $0 start <step_id> [description]"
                exit 1
            fi
            
            start_troubleshooting_session "$step_id" "$description"
            ;;
            
        "end")
            local session_id="${2:-}"
            local outcome="${3:-success}"
            
            if [[ -z "$session_id" ]]; then
                log_error "Session ID is required"
                echo "Usage: $0 end <session_id> [outcome]"
                exit 1
            fi
            
            end_troubleshooting_session "$session_id" "$outcome"
            ;;
            
        "list-steps")
            list_troubleshooting_steps
            ;;
            
        "list-active")
            get_active_sessions
            ;;
            
        "report")
            local format="${2:-console}"
            local step_filter="${3:-*}"  
            local days_back="${4:-30}"
            
            generate_feedback_report "$format" "$step_filter" "$days_back"
            ;;
            
        "interactive")
            run_interactive_session
            ;;
            
        "cleanup")
            troubleshooting_feedback_cleanup
            log_info "✅ Cleanup completed"
            ;;
            
        "help"|"--help"|"-h"|"")
            show_usage
            ;;
            
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"