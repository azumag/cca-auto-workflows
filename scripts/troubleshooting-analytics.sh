#!/bin/bash

# Troubleshooting Analytics Dashboard
# This script provides comprehensive analytics and insights for troubleshooting time validation
# Designed for documentation maintainers to track feedback trends and improve estimates

set -euo pipefail

# Get script directory and source dependencies  
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"
source "$script_dir/lib/troubleshooting-feedback.sh"
source "$script_dir/lib/performance-metrics.sh"

# Configuration
CONFIG_FILE="${CONFIG_FILE:-}"

# Usage information
show_usage() {
    cat << 'EOF'
📊 Troubleshooting Analytics Dashboard

USAGE:
    ./troubleshooting-analytics.sh <command> [options]

COMMANDS:
    dashboard [days]               Show comprehensive analytics dashboard
    trends [step] [days]           Show time trends for troubleshooting steps
    accuracy [days]                Analyze estimate accuracy across all steps
    recommendations [threshold]    Generate estimate update recommendations  
    export <format> [file]         Export analytics data
    monitor                        Real-time monitoring mode

DASHBOARD OPTIONS:
    days                          Number of days to analyze (default: 30)

EXPORT FORMATS:
    json                          JSON format for API consumption
    csv                           CSV format for spreadsheet analysis
    markdown                      Markdown format for documentation

EXAMPLES:
    # Show full analytics dashboard for last 30 days
    ./troubleshooting-analytics.sh dashboard 30
    
    # Analyze trends for authentication issues over 60 days
    ./troubleshooting-analytics.sh trends auth_failure 60
    
    # Get estimate accuracy analysis
    ./troubleshooting-analytics.sh accuracy 90
    
    # Export all data as JSON
    ./troubleshooting-analytics.sh export json analytics_data.json
    
    # Get recommendations for estimates that are off by >50%
    ./troubleshooting-analytics.sh recommendations 50

MONITORING:
    The monitor command provides real-time feedback as users complete
    troubleshooting sessions. Useful for live documentation improvement.

For more information, see docs/TROUBLESHOOTING.md
EOF
}

# Calculate estimate accuracy metrics
calculate_accuracy_metrics() {
    local days_back="$1"
    local feedback_log="$2"
    
    local total_sessions within_estimate significantly_over significantly_under
    total_sessions=0
    within_estimate=0
    significantly_over=0
    significantly_under=0
    
    while IFS=, read -r timestamp session_id step_id outcome duration_min est_range notes; do
        ((total_sessions++))
        
        local min_est_seconds max_est_seconds
        read min_est_seconds max_est_seconds < <(parse_time_estimate "$est_range")
        
        if [[ $min_est_seconds -gt 0 && $max_est_seconds -gt 0 ]]; then
            local duration_seconds
            duration_seconds=$(echo "$duration_min * 60" | bc -l | cut -d. -f1)
            
            if [[ $duration_seconds -ge $min_est_seconds && $duration_seconds -le $max_est_seconds ]]; then
                ((within_estimate++))
            elif [[ $duration_seconds -gt $((max_est_seconds * SIGNIFICANT_MULTIPLIER_OVER)) ]]; then
                ((significantly_over++))
            elif [[ $duration_seconds -lt $((min_est_seconds * SIGNIFICANT_MULTIPLIER_UNDER / 1)) ]]; then
                ((significantly_under++))
            fi
        fi
    done < <(filter_data_by_date "$feedback_log" "$(date -d "${days_back} days ago" '+%Y-%m-%d')")
    
    if [[ $total_sessions -gt 0 ]]; then
        log_header "🎯 Estimate Accuracy Deep Dive"
        log_info "📈 Estimate Accuracy Summary:"
        log_info "  🎯 Within estimate range: $within_estimate/$(( total_sessions )) ($(( within_estimate * 100 / total_sessions ))%)"
        log_info "  🐌 Significantly over (>2x max): $significantly_over ($(( significantly_over * 100 / total_sessions ))%)"
        log_info "  🚀 Significantly under (<0.5x min): $significantly_under ($(( significantly_under * 100 / total_sessions ))%)"
    fi
}

# Analyze difficulty ratings from detailed feedback
analyze_difficulty_ratings() {
    local days_back="$1"
    local detailed_log="$2"
    
    if [[ ! -f "$detailed_log" ]]; then
        return 0
    fi
    
    echo
    log_header "😓 Difficulty Analysis"
    
    local avg_difficulty
    avg_difficulty=$(awk -F, -v cutoff="$(date -d "${days_back} days ago" '+%Y-%m-%d')" '
        BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
        { 
            ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
            if (ts >= cutoff_ts && $7 ~ /^[1-5]$/) {
                sum += $7; count++
            }
        } 
        END { if (count > 0) printf "%.1f", sum/count; else print "0" }' "$detailed_log" 2>/dev/null || echo "0")
    
    if [[ "$avg_difficulty" != "0" ]]; then
        log_info "🎸️  Average difficulty rating: $avg_difficulty/5"
        
        # Show most difficult steps
        log_info "😰 Most Difficult Steps (avg rating ≥4):"
        awk -F, -v cutoff="$(date -d "${days_back} days ago" '+%Y-%m-%d')" '
            BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
            { 
                ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                if (ts >= cutoff_ts && $7 ~ /^[1-5]$/) {
                    step_sum[$3] += $7; step_count[$3]++
                }
            } 
            END { 
                for (step in step_sum) {
                    avg = step_sum[step] / step_count[step]
                    if (avg >= 4.0) {
                        printf "    %-20s: %.1f/5 (%d responses)\n", step, avg, step_count[step]
                    }
                }
            }' "$detailed_log" 2>/dev/null | head -5
    fi
}

# Analyze common blockers from detailed feedback
analyze_common_blockers() {
    local days_back="$1"
    local detailed_log="$2"
    
    if [[ ! -f "$detailed_log" ]]; then
        return 0
    fi
    
    echo
    log_header "🚧 Common Blockers"
    
    local blockers
    blockers=$(awk -F, -v cutoff="$(date -d "${days_back} days ago" '+%Y-%m-%d')" '
        BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
        { 
            ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
            if (ts >= cutoff_ts && length($8) > 3) print $8
        }' "$detailed_log" 2>/dev/null | grep -v '^""$' | sort | uniq -c | sort -nr | head -5)
    
    if [[ -n "$blockers" ]]; then
        log_info "Top reported blockers:"
        echo "$blockers" | while read count blocker; do
            log_info "  [$count×] ${blocker//\"/}"
        done
    fi
}

# Generate comprehensive analytics dashboard (refactored)
show_analytics_dashboard() {
    local days_back="${1:-30}"
    
    log_header "📊 Troubleshooting Analytics Dashboard (Last $days_back days)"
    
    # Generate main feedback report first
    if ! generate_feedback_report "console" "*" "$days_back"; then
        log_warn "No feedback data available. Users need to use the feedback collection tool first."
        echo
        log_info "To collect feedback, users should run:"
        log_info "  ./troubleshooting-feedback.sh interactive"
        return 1
    fi
    
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    local detailed_log="${FEEDBACK_DIR}/detailed_feedback.log"
    
    # Use helper functions for additional analytics
    echo
    calculate_accuracy_metrics "$days_back" "$feedback_log"
    analyze_difficulty_ratings "$days_back" "$detailed_log"
    analyze_common_blockers "$days_back" "$detailed_log"
    
    echo
    log_header "📈 Improvement Opportunities"
    
    # Generate specific recommendations
    generate_improvement_recommendations "$days_back"
}

# Generate improvement recommendations
generate_improvement_recommendations() {
    local days_back="$1"
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    
    # Find steps that need estimate adjustments
    local steps_data
    steps_data=$(awk -F, -v cutoff="$(date -d "${days_back} days ago" '+%Y-%m-%d')" '
        BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
        { 
            ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
            if (ts >= cutoff_ts) {
                step_times[$3] = step_times[$3] " " $5
                step_count[$3]++
            }
        } 
        END { 
            for (step in step_times) {
                if (step_count[step] >= '"$MIN_SESSIONS_FOR_ANALYSIS"') {
                    print step ":" step_times[step]
                }
            }
        }' "$feedback_log" 2>/dev/null)
    
    local recommendations_found=false
    
    while IFS=: read -r step_id times_data; do
        [[ -z "$step_id" ]] && continue
        
        local estimated_range="${TROUBLESHOOTING_STEPS[$step_id]:-Unknown}"
        if [[ "$estimated_range" == "Unknown" ]]; then
            continue
        fi
        
        # Calculate average actual time
        local avg_time
        avg_time=$(echo "$times_data" | tr ' ' '\n' | grep -E '^[0-9.]+$' | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
        
        if [[ "$avg_time" == "0" ]]; then
            continue
        fi
        
        # Parse estimated range
        local min_est_seconds max_est_seconds
        read min_est_seconds max_est_seconds < <(parse_time_estimate "$estimated_range")
        
        if [[ $min_est_seconds -gt 0 && $max_est_seconds -gt 0 ]]; then
            local avg_time_seconds
            avg_time_seconds=$(echo "$avg_time * 60" | bc -l | cut -d. -f1)
            
            # Check if average is significantly outside the range
            local adjustment_needed=false
            local recommendation=""
            
            if [[ $avg_time_seconds -gt $((max_est_seconds + TIME_BUFFER_SECONDS_OVER)) ]]; then
                local suggested_max
                suggested_max=$(( (avg_time_seconds + TIME_BUFFER_SECONDS_ADD) / 60 ))
                recommendation="Consider increasing estimate to $((min_est_seconds / 60))-${suggested_max} minutes"
                adjustment_needed=true
            elif [[ $avg_time_seconds -lt $((min_est_seconds - TIME_BUFFER_SECONDS_UNDER)) ]]; then
                local suggested_min
                suggested_min=$(( (avg_time_seconds - TIME_BUFFER_MINUTES_SUBTRACT) / 60 ))
                [[ $suggested_min -lt 1 ]] && suggested_min=1
                recommendation="Consider decreasing estimate to ${suggested_min}-$((max_est_seconds / 60)) minutes"
                adjustment_needed=true
            fi
            
            if [[ "$adjustment_needed" == "true" ]]; then
                if [[ "$recommendations_found" != "true" ]]; then
                    log_info "💡 Estimate Adjustment Recommendations:"
                    recommendations_found=true
                fi
                log_info "  📝 $step_id: $recommendation"
                log_info "     Current: $estimated_range, Actual avg: ${avg_time} min"
            fi
        fi
    done <<< "$steps_data"
    
    if [[ "$recommendations_found" != "true" ]]; then
        log_info "✅ No significant estimate adjustments needed based on available data"
    fi
    
    # Success rate recommendations
    local low_success_steps
    low_success_steps=$(awk -F, -v cutoff="$(date -d "${days_back} days ago" '+%Y-%m-%d')" '
        BEGIN { cutoff_ts = mktime(gensub(/-/, " ", "g", cutoff) " 00 00 00") }
        { 
            ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
            if (ts >= cutoff_ts) {
                step_total[$3]++
                if ($4 == "success") step_success[$3]++
            }
        } 
        END { 
            for (step in step_total) {
                if (step_total[step] >= '"$MIN_SESSIONS_FOR_ANALYSIS"') {
                    success_rate = (step_success[step] / step_total[step]) * 100
                    if (success_rate < '"$LOW_SUCCESS_RATE_THRESHOLD"') {
                        printf "%s:%.0f:%d\n", step, success_rate, step_total[step]
                    }
                }
            }
        }' "$feedback_log" 2>/dev/null)
    
    if [[ -n "$low_success_steps" ]]; then
        echo
        log_info "⚠️  Steps with Low Success Rates (<70%):"
        
        while IFS=: read -r step_id success_rate total_attempts; do
            [[ -z "$step_id" ]] && continue
            log_info "  🚨 $step_id: ${success_rate}% success rate ($total_attempts attempts)"
            log_info "     Consider improving documentation or adding more examples"
        done <<< "$low_success_steps"
    fi
}

# Show time trends for specific steps
show_time_trends() {
    local step_filter="${1:-*}"
    local days_back="${2:-30}"
    
    log_header "📈 Time Trends Analysis"
    
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    if [[ ! -f "$feedback_log" ]]; then
        log_warn "No feedback data available"
        return 1
    fi
    
    # Show trends by week for the specified period
    local weeks_back=$(( (days_back + 6) / 7 ))
    
    log_info "📊 Weekly Time Trends (Last $weeks_back weeks):"
    echo
    
    for ((week=weeks_back-1; week>=0; week--)); do
        local week_start week_end
        week_start=$(date -d "${week} weeks ago" '+%Y-%m-%d')
        week_end=$(date -d "$((week-1)) weeks ago" '+%Y-%m-%d')
        
        local week_data
        if [[ "$step_filter" == "*" ]]; then
            week_data=$(awk -F, -v start="$week_start" -v end="$week_end" '
                BEGIN { 
                    start_ts = mktime(gensub(/-/, " ", "g", start) " 00 00 00")
                    end_ts = mktime(gensub(/-/, " ", "g", end) " 00 00 00")
                }
                { 
                    ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                    if (ts >= start_ts && ts < end_ts) print $5
                }' "$feedback_log" 2>/dev/null)
        else
            week_data=$(awk -F, -v start="$week_start" -v end="$week_end" -v step="$step_filter" '
                BEGIN { 
                    start_ts = mktime(gensub(/-/, " ", "g", start) " 00 00 00")
                    end_ts = mktime(gensub(/-/, " ", "g", end) " 00 00 00")
                }
                { 
                    ts = mktime(gensub(/[-:T]/, " ", "g", gensub(/\+.*/, "", 1, $1)) " 00")
                    if (ts >= start_ts && ts < end_ts && $3 == step) print $5
                }' "$feedback_log" 2>/dev/null)
        fi
        
        if [[ -n "$week_data" ]]; then
            local session_count avg_time
            session_count=$(echo "$week_data" | wc -l)
            avg_time=$(echo "$week_data" | awk '{sum+=$1; count++} END {if(count>0) printf "%.1f", sum/count; else print "0"}')
            
            printf "  Week of %-10s: %2d sessions, avg %.1f min\n" "$week_start" "$session_count" "$avg_time"
        else
            printf "  Week of %-10s: %2d sessions, avg %.1f min\n" "$week_start" 0 0
        fi
    done
}

# Export analytics data in various formats
export_analytics_data() {
    local format="$1"
    local output_file="${2:-troubleshooting_analytics.${format}}"
    
    case "$format" in
        "json")
            export_json_analytics "$output_file"
            ;;
        "csv")
            export_csv_analytics "$output_file"
            ;;
        "markdown")
            export_markdown_analytics "$output_file"
            ;;
        *)
            log_error "Unsupported export format: $format"
            return 1
            ;;
    esac
    
    log_info "📤 Analytics exported to: $output_file"
}

# Export JSON format analytics
export_json_analytics() {
    local output_file="$1"
    
    # Use the existing JSON report function and enhance it
    generate_feedback_report "json" "*" 30 > "$output_file"
}

# Export CSV format analytics  
export_csv_analytics() {
    local output_file="$1"
    local feedback_log="${FEEDBACK_DIR}/feedback.log"
    
    cat > "$output_file" << 'EOF'
timestamp,session_id,step_id,outcome,actual_duration_minutes,estimated_time_range,notes
EOF
    
    if [[ -f "$feedback_log" ]]; then
        cat "$feedback_log" >> "$output_file"
    fi
}

# Export Markdown format analytics
export_markdown_analytics() {
    local output_file="$1"
    
    cat > "$output_file" << EOF
# Troubleshooting Analytics Report

Generated: $(date -Iseconds)

## Summary

$(generate_feedback_report "console" "*" 30 | grep -A 20 "📈 Overall Statistics:")

## Recommendations

$(generate_improvement_recommendations 30)

## Data Export

Raw data is available in CSV format for further analysis.
Use \`./troubleshooting-analytics.sh export csv\` to generate machine-readable data.

EOF
}

# Real-time monitoring mode
monitor_feedback() {
    log_header "📡 Real-time Troubleshooting Feedback Monitor"
    
    log_info "Monitoring for new troubleshooting sessions..."
    log_info "Press Ctrl+C to stop monitoring"
    echo
    
    local last_session_count=0
    
    while true; do
        local current_session_count
        current_session_count=$(find "$FEEDBACK_DIR" -name "*.session" -type f 2>/dev/null | wc -l)
        
        if [[ $current_session_count -gt $last_session_count ]]; then
            log_info "🔄 New troubleshooting session started (active sessions: $current_session_count)"
            get_active_sessions
            last_session_count=$current_session_count
        elif [[ $current_session_count -lt $last_session_count ]]; then
            log_info "✅ Troubleshooting session completed (active sessions: $current_session_count)"
            
            # Show quick stats from the last completed session
            local feedback_log="${FEEDBACK_DIR}/feedback.log"
            if [[ -f "$feedback_log" ]]; then
                local latest_entry
                latest_entry=$(tail -1 "$feedback_log")
                if [[ -n "$latest_entry" ]]; then
                    local step_id outcome duration
                    IFS=, read -r timestamp session_id step_id outcome duration est_range notes <<< "$latest_entry"
                    log_info "   Step: $step_id, Outcome: $outcome, Duration: ${duration} min"
                fi
            fi
            
            last_session_count=$current_session_count
        fi
        
        sleep 5
    done
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
        "dashboard")
            local days="${2:-30}"
            show_analytics_dashboard "$days"
            ;;
            
        "trends")
            local step="${2:-*}"
            local days="${3:-30}"
            show_time_trends "$step" "$days"
            ;;
            
        "accuracy")
            local days="${2:-30}"
            show_analytics_dashboard "$days" | grep -A 20 "🎯 Estimate Accuracy"
            ;;
            
        "recommendations")
            local days="${2:-30}"
            echo
            generate_improvement_recommendations "$days"
            ;;
            
        "export")
            local format="${2:-json}"
            local file="${3:-}"
            export_analytics_data "$format" "$file"
            ;;
            
        "monitor")
            monitor_feedback
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