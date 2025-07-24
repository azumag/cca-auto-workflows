#!/bin/bash

# Troubleshooting feedback collection module for Claude Code Auto Workflows
# This module provides user feedback collection and analysis for troubleshooting time validation

# Source dependencies
troubleshooting_feedback_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$troubleshooting_feedback_script_dir/common.sh"
source "$troubleshooting_feedback_script_dir/performance-metrics.sh"

# Troubleshooting feedback configuration
FEEDBACK_DIR="${TMPDIR:-/tmp}/troubleshooting-feedback"
FEEDBACK_RETENTION_DAYS=90

# Known troubleshooting steps from documentation with their estimated times
declare -A TROUBLESHOOTING_STEPS=(
    ["range_fix"]="2-5 minutes"
    ["enum_fix"]="1-3 minutes"  
    ["dependency_fix"]="5-10 minutes"
    ["export_fix"]="2-5 minutes"
    ["name_fix"]="1-3 minutes"
    ["value_fix"]="2-5 minutes"
    ["path_fix"]="3-8 minutes"
    ["syntax_fix"]="3-7 minutes"
    ["perm_fix"]="5-15 minutes"
    ["order_fix"]="10-20 minutes"
    ["slow_config"]="10-25 minutes"
    ["resource_config"]="15-30 minutes"
    ["consistency_config"]="20-45 minutes"
    ["output_check"]="3-8 minutes"
    ["log_check"]="5-12 minutes"
    ["cache_check"]="8-20 minutes"
    ["rate_check"]="10-25 minutes"
    ["label_check"]="2-5 minutes"
    ["event_check"]="5-10 minutes"
    ["branch_check"]="10-15 minutes"
    ["auth_failure"]="10-20 minutes"
    ["rate_failure"]="15-30 minutes"
    ["script_failure"]="5-15 minutes"
    ["claude_response"]="10-25 minutes"
    ["claude_instructions"]="5-10 minutes"
    ["claude_timeout"]="20-45 minutes"
    ["repo_access"]="15-30 minutes"
    ["token_scope"]="10-20 minutes"
    ["org_policy"]="30-120 minutes"
    ["api_solutions"]="15-30 minutes"
    ["api_optimize"]="30-60 minutes"
    ["cpu_optimize"]="10-20 minutes"
    ["io_optimize"]="20-45 minutes"
    ["network_optimize"]="15-35 minutes"
    ["memory_solutions"]="10-25 minutes"
    ["memory_debug"]="30-90 minutes"
    ["cache_improve"]="25-45 minutes"
    ["cache_fix"]="10-25 minutes"
)

# Initialize troubleshooting feedback module
troubleshooting_feedback_init() {
    setup_cache "$FEEDBACK_DIR" 
    cleanup_cache "$FEEDBACK_DIR" $((FEEDBACK_RETENTION_DAYS * 24 * 60 * 60))
    
    log_info "Troubleshooting feedback collection initialized"
}

# Display available troubleshooting steps
list_troubleshooting_steps() {
    log_header "📋 Available Troubleshooting Steps"
    
    local step_id step_estimate
    for step_id in "${!TROUBLESHOOTING_STEPS[@]}"; do
        step_estimate="${TROUBLESHOOTING_STEPS[$step_id]}"
        printf "  %-20s -> %s\n" "$step_id" "$step_estimate"
    done | sort
}

# Convert time range to seconds for comparison
parse_time_estimate() {
    local time_estimate="$1"
    
    # Extract min and max from "X-Y minutes" format
    local min_time max_time
    if [[ "$time_estimate" =~ ([0-9]+)-([0-9]+)\ minutes ]]; then
        min_time="${BASH_REMATCH[1]}"
        max_time="${BASH_REMATCH[2]}"
        echo "$((min_time * 60)) $((max_time * 60))"
    else
        echo "0 0"
    fi
}

# Start tracking a troubleshooting session
start_troubleshooting_session() {
    local step_id="$1"
    local description="${2:-No description provided}"
    
    if [[ -z "${TROUBLESHOOTING_STEPS[$step_id]:-}" ]]; then
        log_error "Unknown troubleshooting step: $step_id"
        log_info "Use 'list_troubleshooting_steps' to see available steps"
        return 1
    fi
    
    local session_id="troubleshooting_${step_id}_$(date +%s)"
    local session_file="${FEEDBACK_DIR}/${session_id}.session"
    
    cat > "$session_file" << EOF
{
    "session_id": "$session_id",
    "step_id": "$step_id",
    "description": "$description",
    "estimated_time_range": "${TROUBLESHOOTING_STEPS[$step_id]}",
    "start_time": "$(date -Iseconds)",
    "start_timestamp": $(date +%s.%N),
    "status": "in_progress"
}
EOF
    
    local estimated_range="${TROUBLESHOOTING_STEPS[$step_id]}"
    log_info "🚀 Started troubleshooting session: $session_id"
    log_info "   Step: $step_id (estimated: $estimated_range)"
    log_info "   Description: $description"
    log_info "   Use 'end_troubleshooting_session $session_id [success|failure]' when done"
    
    echo "$session_id"
}

# End tracking a troubleshooting session and collect feedback
end_troubleshooting_session() {
    local session_id="$1"
    local outcome="${2:-success}"
    local user_notes="${3:-}"
    
    local session_file="${FEEDBACK_DIR}/${session_id}.session"
    if [[ ! -f "$session_file" ]]; then
        log_error "Session not found: $session_id"
        return 1
    fi
    
    # Read session data
    local session_data
    session_data=$(cat "$session_file")
    local step_id start_timestamp estimated_range
    step_id=$(echo "$session_data" | jq -r '.step_id')
    start_timestamp=$(echo "$session_data" | jq -r '.start_timestamp')
    estimated_range=$(echo "$session_data" | jq -r '.estimated_time_range')
    
    # Calculate actual duration
    local end_timestamp actual_duration_seconds actual_duration_minutes
    end_timestamp=$(date +%s.%N)
    actual_duration_seconds=$(echo "$end_timestamp - $start_timestamp" | bc -l)
    actual_duration_minutes=$(echo "$actual_duration_seconds / 60" | bc -l)
    
    # Update session file with completion data
    local updated_session
    updated_session=$(echo "$session_data" | jq --arg outcome "$outcome" \
        --arg end_time "$(date -Iseconds)" \
        --arg end_timestamp "$end_timestamp" \
        --arg duration_seconds "$actual_duration_seconds" \
        --arg duration_minutes "$actual_duration_minutes" \
        --arg user_notes "$user_notes" \
        '. + {
            "outcome": $outcome,
            "end_time": $end_time,
            "end_timestamp": ($end_timestamp | tonumber),
            "actual_duration_seconds": ($duration_seconds | tonumber),
            "actual_duration_minutes": ($duration_minutes | tonumber),
            "user_notes": $user_notes,
            "status": "completed"
        }')
    
    echo "$updated_session" > "$session_file"
    
    # Log to main feedback database
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    echo "$(date -Iseconds),$session_id,$step_id,$outcome,${actual_duration_minutes},\"$estimated_range\",\"$user_notes\"" >> "$feedback_log"
    
    # Provide immediate feedback to user
    log_info "✅ Completed troubleshooting session: $session_id"
    log_info "   Outcome: $outcome"
    log_info "   Actual time: $(printf '%.1f' "$actual_duration_minutes") minutes"
    log_info "   Estimated time: $estimated_range"
    
    # Compare with estimate
    local min_est_seconds max_est_seconds
    read min_est_seconds max_est_seconds < <(parse_time_estimate "$estimated_range")
    
    if [[ $min_est_seconds -gt 0 && $max_est_seconds -gt 0 ]]; then
        local duration_seconds_int
        duration_seconds_int=$(printf '%.0f' "$actual_duration_seconds")
        
        if [[ $duration_seconds_int -lt $min_est_seconds ]]; then
            log_info "   🚀 Faster than estimated! ($(( (min_est_seconds - duration_seconds_int) / 60 )) minutes under minimum)"
        elif [[ $duration_seconds_int -gt $max_est_seconds ]]; then
            log_info "   ⏰ Slower than estimated ($(( (duration_seconds_int - max_est_seconds) / 60 )) minutes over maximum)"
        else
            log_info "   🎯 Within estimated time range"
        fi
    fi
    
    # Clean up session file
    rm -f "$session_file"
    
    # Prompt for additional feedback if interactive
    if [[ -t 0 && -t 1 ]]; then
        collect_detailed_feedback "$session_id" "$step_id" "$outcome" "$actual_duration_minutes" "$estimated_range"
    fi
}

# Collect detailed feedback interactively
collect_detailed_feedback() {
    local session_id="$1"
    local step_id="$2" 
    local outcome="$3"
    local actual_minutes="$4"
    local estimated_range="$5"
    
    echo
    log_info "📝 Optional: Help improve our time estimates!"
    echo
    
    # Ask for difficulty rating
    local difficulty
    while true; do
        read -p "How difficult was this troubleshooting step? (1=very easy, 5=very hard) [3]: " difficulty
        difficulty=${difficulty:-3}
        if [[ "$difficulty" =~ ^[1-5]$ ]]; then
            break
        fi
        echo "Please enter a number from 1 to 5"
    done
    
    # Ask about blockers or helpful resources
    local blockers
    read -p "Were there any blockers or issues not covered in the documentation? (optional): " blockers
    
    local helpful_resources
    read -p "What resources or tools were most helpful? (optional): " helpful_resources
    
    # Ask for estimate feedback
    local estimate_feedback
    echo "Estimated time was: $estimated_range"
    echo "Your actual time was: $(printf '%.1f' "$actual_minutes") minutes"
    read -p "Should the time estimate be adjusted? (shorter/longer/accurate) [accurate]: " estimate_feedback
    estimate_feedback=${estimate_feedback:-accurate}
    
    # Save detailed feedback
    local detailed_feedback_file="${FEEDBACK_DIR}/detailed_feedback.log"
    cat >> "$detailed_feedback_file" << EOF
$(date -Iseconds),$session_id,$step_id,$outcome,$(printf '%.1f' "$actual_minutes"),"$estimated_range",$difficulty,"$blockers","$helpful_resources","$estimate_feedback"
EOF
    
    log_info "✅ Thank you for your feedback! This helps improve our documentation."
}

# Generate feedback analytics report
generate_feedback_report() {
    local output_format="${1:-console}"
    local step_filter="${2:-*}"
    local days_back="${3:-30}"
    
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    local detailed_log="${FEEDBACK_DIR}/detailed_feedback.log"
    
    if [[ ! -f "$feedback_log" ]]; then
        log_warn "No feedback data available yet"
        return 1
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "${days_back} days ago" '+%Y-%m-%d')
    
    if [[ "$output_format" == "console" ]]; then
        generate_console_feedback_report "$step_filter" "$cutoff_date"
    elif [[ "$output_format" == "json" ]]; then
        generate_json_feedback_report "$step_filter" "$cutoff_date"
    else
        log_error "Unsupported output format: $output_format"
        return 1
    fi
}

# Generate console format feedback report
generate_console_feedback_report() {
    local step_filter="$1"
    local cutoff_date="$2"
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    
    log_header "📊 Troubleshooting Feedback Report (Last 30 days)"
    echo
    
    # Filter data by date and step
    local filtered_data
    if [[ "$step_filter" == "*" ]]; then
        filtered_data=$(awk -F, -v cutoff="$cutoff_date" '
            BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
            { 
                ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                if (ts >= cutoff_ts) print $0
            }' "$feedback_log")
    else
        filtered_data=$(awk -F, -v cutoff="$cutoff_date" -v step="$step_filter" '
            BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
            { 
                ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                if (ts >= cutoff_ts && $3 == step) print $0
            }' "$feedback_log")
    fi
    
    if [[ -z "$filtered_data" ]]; then
        log_info "No feedback data found for the specified criteria"
        return 0
    fi
    
    # Overall statistics
    local total_sessions successful_sessions
    total_sessions=$(echo "$filtered_data" | wc -l)
    successful_sessions=$(echo "$filtered_data" | grep -c ",success," || echo 0)
    
    log_info "📈 Overall Statistics:"
    log_info "  📊 Total troubleshooting sessions: $total_sessions"
    log_info "  ✅ Successful sessions: $successful_sessions ($(( successful_sessions * 100 / total_sessions ))%)"
    log_info "  ❌ Failed sessions: $(( total_sessions - successful_sessions )) ($(( (total_sessions - successful_sessions) * 100 / total_sessions ))%)"
    echo
    
    # Step-by-step analysis
    log_info "🔍 Step-by-Step Analysis:"
    
    # Get unique steps from filtered data
    local steps
    steps=$(echo "$filtered_data" | cut -d, -f3 | sort | uniq)
    
    while IFS= read -r step; do
        [[ -z "$step" ]] && continue
        
        local step_data
        step_data=$(echo "$filtered_data" | grep ",$step,")
        
        local step_total step_successful step_avg_time
        step_total=$(echo "$step_data" | wc -l)
        step_successful=$(echo "$step_data" | grep -c ",success," || echo 0)
        step_avg_time=$(echo "$step_data" | cut -d, -f5 | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
        
        local estimated_range
        estimated_range="${TROUBLESHOOTING_STEPS[$step]:-Unknown}"
        
        printf "  %-20s | Sessions: %2d | Success: %3d%% | Avg Time: %5.1f min | Estimated: %s\n" \
            "$step" "$step_total" "$(( step_successful * 100 / step_total ))" "$step_avg_time" "$estimated_range"
        
        # Time accuracy analysis
        if [[ "$estimated_range" != "Unknown" ]]; then
            local min_est_seconds max_est_seconds
            read min_est_seconds max_est_seconds < <(parse_time_estimate "$estimated_range")
            
            if [[ $min_est_seconds -gt 0 && $max_est_seconds -gt 0 ]]; then
                local within_range under_range over_range
                within_range=0
                under_range=0
                over_range=0
                
                while IFS=, read -r timestamp session_id step_id outcome duration_min est_range notes; do
                    local duration_seconds
                    duration_seconds=$(echo "$duration_min * 60" | bc -l | cut -d. -f1)
                    
                    if [[ $duration_seconds -lt $min_est_seconds ]]; then
                        ((under_range++))
                    elif [[ $duration_seconds -gt $max_est_seconds ]]; then
                        ((over_range++))
                    else
                        ((within_range++))
                    fi
                done <<< "$step_data"
                
                local total=$step_total
                printf "    📊 Time Accuracy: Within range %d%% | Under %d%% | Over %d%%\n" \
                    "$(( within_range * 100 / total ))" \
                    "$(( under_range * 100 / total ))" \
                    "$(( over_range * 100 / total ))"
            fi
        fi
        echo
    done <<< "$steps"
    
    # Recommendations
    log_info "💡 Recommendations:"
    
    # Find steps with consistently poor time estimates
    while IFS= read -r step; do
        [[ -z "$step" ]] && continue
        
        local step_data
        step_data=$(echo "$filtered_data" | grep ",$step,")
        local step_total
        step_total=$(echo "$step_data" | wc -l)
        
        # Only analyze steps with enough data
        if [[ $step_total -ge 3 ]]; then
            local estimated_range
            estimated_range="${TROUBLESHOOTING_STEPS[$step]:-Unknown}"
            
            if [[ "$estimated_range" != "Unknown" ]]; then
                local min_est_seconds max_est_seconds
                read min_est_seconds max_est_seconds < <(parse_time_estimate "$estimated_range")
                
                if [[ $min_est_seconds -gt 0 && $max_est_seconds -gt 0 ]]; then
                    local over_count
                    over_count=0
                    
                    while IFS=, read -r timestamp session_id step_id outcome duration_min est_range notes; do
                        local duration_seconds
                        duration_seconds=$(echo "$duration_min * 60" | bc -l | cut -d. -f1)
                        
                        if [[ $duration_seconds -gt $max_est_seconds ]]; then
                            ((over_count++))
                        fi
                    done <<< "$step_data"
                    
                    # If more than 60% of sessions exceed the estimate, recommend adjustment
                    if [[ $(( over_count * 100 / step_total )) -gt 60 ]]; then
                        local avg_time
                        avg_time=$(echo "$step_data" | cut -d, -f5 | awk '{sum+=$1; count++} END {if(count>0) printf "%.0f", sum/count; else print "0"}')
                        log_info "  ⚠️  Consider increasing estimate for '$step' to ~$((avg_time + 5)) minutes (currently $estimated_range)"
                    fi
                fi
            fi
        fi
    done <<< "$steps"
}

# Generate JSON format feedback report
generate_json_feedback_report() {
    local step_filter="$1"
    local cutoff_date="$2"
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    
    # Filter and process data similar to console report but output as JSON
    local filtered_data
    if [[ "$step_filter" == "*" ]]; then
        filtered_data=$(awk -F, -v cutoff="$cutoff_date" '
            BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
            { 
                ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                if (ts >= cutoff_ts) print $0
            }' "$feedback_log")
    else
        filtered_data=$(awk -F, -v cutoff="$cutoff_date" -v step="$step_filter" '
            BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
            { 
                ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                if (ts >= cutoff_ts && $3 == step) print $0
            }' "$feedback_log")
    fi
    
    # Generate JSON output
    cat << EOF
{
    "report_generated": "$(date -Iseconds)",
    "filter": {
        "step": "$step_filter",
        "days_back": $(( ($(date +%s) - $(date -d "$cutoff_date" +%s)) / 86400 ))
    },
    "summary": {
        "total_sessions": $(echo "$filtered_data" | wc -l),
        "successful_sessions": $(echo "$filtered_data" | grep -c ",success," || echo 0),
        "failed_sessions": $(echo "$filtered_data" | grep -c ",failure," || echo 0)
    },
    "steps": [
EOF
    
    # Process each step
    local steps first_step=true
    steps=$(echo "$filtered_data" | cut -d, -f3 | sort | uniq)
    
    while IFS= read -r step; do
        [[ -z "$step" ]] && continue
        
        if [[ "$first_step" != "true" ]]; then
            echo ","
        fi
        first_step=false
        
        local step_data
        step_data=$(echo "$filtered_data" | grep ",$step,")
        
        local step_total step_successful step_avg_time
        step_total=$(echo "$step_data" | wc -l)
        step_successful=$(echo "$step_data" | grep -c ",success," || echo 0)
        step_avg_time=$(echo "$step_data" | cut -d, -f5 | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
        
        cat << EOF
        {
            "step_id": "$step",
            "estimated_time_range": "${TROUBLESHOOTING_STEPS[$step]:-Unknown}",
            "sessions": $step_total,
            "successful_sessions": $step_successful,
            "success_rate_percent": $(( step_successful * 100 / step_total )),
            "average_actual_time_minutes": $step_avg_time
        }
EOF
    done <<< "$steps"
    
    cat << EOF
    ]
}
EOF
}

# Get active troubleshooting sessions
get_active_sessions() {
    local active_sessions
    active_sessions=$(find "$FEEDBACK_DIR" -name "*.session" -type f 2>/dev/null)
    
    if [[ -z "$active_sessions" ]]; then
        log_info "No active troubleshooting sessions"
        return 0
    fi
    
    log_info "🔄 Active Troubleshooting Sessions:"
    
    while IFS= read -r session_file; do
        local session_data step_id start_time description
        session_data=$(cat "$session_file")
        step_id=$(echo "$session_data" | jq -r '.step_id')
        start_time=$(echo "$session_data" | jq -r '.start_time')
        description=$(echo "$session_data" | jq -r '.description')
        
        local session_id
        session_id=$(basename "$session_file" .session)
        
        log_info "  📋 $session_id"
        log_info "     Step: $step_id"
        log_info "     Started: $start_time" 
        log_info "     Description: $description"
        echo
    done <<< "$active_sessions"
}

# Cleanup troubleshooting feedback module
troubleshooting_feedback_cleanup() {
    # Clean up old session files
    find "$FEEDBACK_DIR" -name "*.session" -mtime +1 -delete 2>/dev/null || true
    
    # Archive old feedback logs
    local archive_date
    archive_date=$(date -d "${FEEDBACK_RETENTION_DAYS} days ago" '+%Y-%m-%d')
    
    for log_file in feedback.log detailed_feedback.log; do
        local full_path="${FEEDBACK_DIR}/${log_file}"
        if [[ -f "$full_path" ]]; then
            # Remove entries older than retention period
            local temp_file="${full_path}.tmp"
            awk -F, -v cutoff="$archive_date" '
                BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
                { 
                    ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                    if (ts >= cutoff_ts) print $0
                }' "$full_path" > "$temp_file" && mv "$temp_file" "$full_path"
        fi
    done
    
    log_info "Troubleshooting feedback cleanup completed"
}