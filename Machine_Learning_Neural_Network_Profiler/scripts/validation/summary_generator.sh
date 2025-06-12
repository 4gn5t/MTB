#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../utils/colors.sh"

create_validation_summary() {
    local validation_dir="$1"
    local summary_file="$validation_dir/validation_summary.md"

    print_status "INFO" "Creating validation summary report..."

    cat > "$summary_file" << EOF
# ML-Configurator Validation Summary

Validation date: $(date)

## Model Validation Results

EOF

    for info_file in "$validation_dir"/*_info.txt; do
        if [[ -f "$info_file" ]]; then
            local model_name=$(basename "$info_file" _info.txt)
            echo "### $model_name" >> "$summary_file"
            echo "" >> "$summary_file"
            echo '```' >> "$summary_file"
            cat "$info_file" >> "$summary_file"
            echo '```' >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done
    
    local error_count=0
    for error_file in "$validation_dir"/*_error.txt; do
        if [[ -f "$error_file" ]]; then
            if [[ $error_count -eq 0 ]]; then
                echo "## Validation Errors" >> "$summary_file"
                echo "" >> "$summary_file"
            fi
            
            local model_name=$(basename "$error_file" _error.txt)
            echo "### $model_name (ERROR)" >> "$summary_file"
            echo "" >> "$summary_file"
            echo '```' >> "$summary_file"
            head -20 "$error_file" >> "$summary_file"
            echo '```' >> "$summary_file"
            echo "" >> "$summary_file"
            
            ((error_count++))
        fi
    done
    
    if [[ $error_count -eq 0 ]]; then
        echo "## Status: All models passed validation" >> "$summary_file"
    else
        echo "## Status: $error_count model(s) failed validation" >> "$summary_file"
    fi

    print_status "SUCCESS" "Summary report created: $summary_file"
}
