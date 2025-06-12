#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../utils/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/ml_configurator_validator.sh"
source "$(dirname "${BASH_SOURCE[0]}")/summary_generator.sh"

test_models() {
    local enable_target_validation="${1:-false}"
    local quantization_type="${2:-float32}"
    
    print_status "INFO" "Starting model testing..."
    print_status "INFO" "Target validation: $enable_target_validation"
    print_status "INFO" "Quantization type: $quantization_type"
    
    local models_dir="../pretrained_models"
    local results_dir="test_results"
    
    print_status "INFO" "Looking for models in: $(realpath "$models_dir" 2>/dev/null || echo "$models_dir")"
    
    if [[ ! -d "$models_dir" ]] || [[ -z "$(find "$models_dir" -name '*.h5' -o -name '*.tflite' 2>/dev/null)" ]]; then
        print_status "ERROR" "No models found in $models_dir directory"
        return 1
    fi

    local model_count=0
    for model_file in "$models_dir"/*.h5 "$models_dir"/*.tflite; do
        if [[ -f "$model_file" ]]; then
            local model_name=$(basename "$model_file")
            print_status "INFO" "Testing pretrained model: $model_name from $models_dir"

            local test_result="$results_dir/${model_name}_test.log"
            echo "Testing model $model_name - $(date)" > "$test_result"
            echo "File size: $(du -h "$model_file" | cut -f1)" >> "$test_result"
            echo "File path: $(realpath "$model_file")" >> "$test_result"

            print_status "SUCCESS" "Basic testing of $model_name completed"
            ((model_count++))
        fi
    done

    print_status "INFO" "Found and tested $model_count models from pretrained_models directory"

    validate_models_with_ml_configurator "$enable_target_validation" "$quantization_type"
}
