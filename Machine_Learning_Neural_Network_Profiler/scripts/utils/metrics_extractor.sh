#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

extract_model_metrics() {
    local log_file="$1"
    local metrics=""
    
    if grep -q "Overview of model resource info:" "$log_file"; then
        metrics=$(awk '/Overview of model resource info:/,/^\+.*\+$/' "$log_file" | tail -n +3)
    fi
    
    local cycles=$(grep -o "Cycles.*|.*[0-9].*|" "$log_file" | head -1 | awk -F'|' '{print $3}' | xargs)
    local model_mem=$(grep -o "Model.*Memory.*|.*[0-9].*|" "$log_file" | head -1 | awk -F'|' '{print $3}' | xargs)
    local scratch_mem=$(grep -o "Scratch.*Memory.*|.*[0-9].*|" "$log_file" | head -1 | awk -F'|' '{print $3}' | xargs)
    
    if [[ -n "$cycles" && -n "$model_mem" && -n "$scratch_mem" ]]; then
        echo -e "    ${BLUE}Cycles: ${cycles}, Model Memory: ${model_mem} bytes, Scratch Memory: ${scratch_mem} bytes${NC}"
    fi
    
    if [[ -n "$metrics" ]]; then
        echo "$metrics"
    fi
}

extract_validation_metrics() {
    local log_file="$1"
    local metrics=""
    
    if grep -q "Cross-domain validation passed\|Cross-domain validation failed" "$log_file"; then
        metrics=$(awk '/Cross-domain validation.*for the float:/,/^\+.*\+$/' "$log_file" | tail -n +3 | head -n -1)
        
        if [[ -z "$metrics" ]]; then
            metrics=$(awk '/Cross-domain validation.*for the int8x8:/,/^\+.*\+$/' "$log_file" | tail -n +3 | head -n -1)
        fi
        
        if [[ -z "$metrics" ]]; then
            metrics=$(awk '/Cross-domain validation/,/^\+.*\+$/' "$log_file" | grep -A 10 "Metric.*Actual.*Required.*Status" | tail -n +2 | head -n -1)
        fi
        
        if [[ -n "$metrics" ]]; then
            echo "$metrics"
        fi
    fi
}

extract_failed_metrics() {
    local log_file="$1"
    local failed_metrics=""
    
    if grep -q "Cross-domain validation failed" "$log_file"; then
        failed_metrics=$(awk '/Cross-domain validation failed.*for the float:/,/^\+.*\+$/' "$log_file" | tail -n +3 | head -n -1)
        
        if [[ -z "$failed_metrics" ]]; then
            failed_metrics=$(awk '/Cross-domain validation failed.*for the int8x8:/,/^\+.*\+$/' "$log_file" | tail -n +3 | head -n -1)
        fi
        
        if [[ -z "$failed_metrics" ]]; then
            failed_metrics=$(awk '/Cross-domain validation failed/,/^\+.*\+$/' "$log_file" | grep -A 10 "Metric.*Actual.*Required.*Status" | tail -n +2 | head -n -1)
        fi
        
        if [[ -n "$failed_metrics" ]]; then
            echo "$failed_metrics"
        fi
    fi
}

extract_error_details() {
    local log_file="$1"
    local errors=""
    
    errors=$(grep -i "ERROR\|FAIL\|Exception\|failed" "$log_file" | tail -5)
    
    if [[ -z "$errors" ]]; then
        errors=$(tail -10 "$log_file" | grep -v "^\[INFO\]" | head -3)
    fi
    
    echo "$errors"
}

extract_target_validation_metrics() {
    local log_file="$1"
    local metrics=""
    
    if grep -q "Target validation.*passed\|Target.*validation.*success" "$log_file"; then
        metrics=$(awk '/Target validation.*for the int8x8:/,/^\+.*\+$/' "$log_file" | tail -n +3 | head -n -1)
        
        if [[ -z "$metrics" ]]; then
            metrics=$(awk '/Target validation/,/^\+.*\+$/' "$log_file" | grep -A 10 "Metric.*Target.*Host.*Status" | tail -n +2 | head -n -1)
        fi
        
        if [[ -n "$metrics" ]]; then
            echo "$metrics"
        fi
    fi
}

extract_target_error_details() {
    local log_file="$1"
    local errors=""
    
    errors=$(grep -i "target.*error\|target.*fail\|device.*not.*found\|connection.*failed\|uart.*error" "$log_file" | tail -3)
    
    if [[ -z "$errors" ]]; then
        errors=$(grep -A 5 -i "target.*validation" "$log_file" | grep -i "error\|fail\|warning" | tail -3)
    fi
    
    echo "$errors"
}
