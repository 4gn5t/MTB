#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../utils/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/metrics_extractor.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../utils/mtbml_config.sh"


validate_models_with_ml_configurator() {
    print_status "START" "Validating models with ml-configurator-cli..."

    local models_dir="../pretrained_models"
    local test_data_dir="../test_data"
    local results_dir="test_results"
    local validation_dir="$results_dir/ml_configurator_validation"
    
    mkdir -p "$validation_dir"
    
    local test_data_file="$test_data_dir/test_data.csv"
    if [[ -f "$test_data_file" ]]; then
        print_status "INFO" "Found test data at: $(realpath "$test_data_file")"
    else
        print_status "ERROR" "Test data not found at: $(realpath "$test_data_dir")/test_data.csv"
        print_status "INFO" "Current working directory: $(pwd)"
        print_status "INFO" "Looking for test data in: $(realpath "$test_data_dir" 2>/dev/null || echo "$test_data_dir")"
        return 1
    fi
    
    local enable_target_validation=false
    if [[ "$1" == "--enable-target" ]]; then
        enable_target_validation=true
        print_status "INFO" "Target validation enabled"
    else
        print_status "INFO" "Target validation disabled (use --enable-target to enable)"
    fi
    
    if ! command -v ml-configurator-cli &> /dev/null; then
        print_status "WARNING" "ml-configurator-cli not found, creating mock validation results"
        create_validation_summary "$validation_dir"
        return 0
    fi
    
    for model_file in "$models_dir"/*.h5 "$models_dir"/*.tflite; do
        if [[ -f "$model_file" ]]; then
            local model_basename=$(basename "$model_file")
            local model_name="${model_basename%.*}"

            echo ""
            print_status "START" "Processing model $model_name"

            local config_file="$validation_dir/${model_name}_config.mtbml"
            local validation_log="$validation_dir/${model_name}_validation.log"

            local model_test_data="$test_data_dir/test_data.csv"

            local source_config="$models_dir/${model_name}.mtbml"
            if [[ ! -f "$source_config" ]]; then
                source_config="$models_dir/${model_basename}.mtbml"
            fi
            
            if [[ -f "$source_config" ]]; then
                print_status "INFO" "Using existing config for $model_name"
                cp "$source_config" "$config_file"
            else
                print_status "INFO" "Config file not found for $model_name, generating basic config"
                if [[ -f "$model_test_data" ]]; then
                    generate_basic_mtbml_config "$model_file" "$config_file" "$model_name" "$model_test_data"
                else
                    print_status "WARNING" "No test data found for $model_name (looked in $test_data_dir), skipping"
                    continue
                fi
            fi

            if [[ ! -f "$model_test_data" ]]; then
                print_status "WARNING" "Test data not found for $model_name, skipping validation"
                continue
            fi

            local data_size=$(wc -l < "$model_test_data" 2>/dev/null || echo "0")
            print_status "INFO" "Using test data: $model_test_data ($data_size lines)"

            print_status "INFO" "About to run ml-configurator-cli from directory: $validation_dir"
            print_status "INFO" "Config file: ${model_name}_config.mtbml"
            
            cd "$validation_dir"
            if [[ ! -f "../../../test_data/test_data.csv" ]]; then
                print_status "ERROR" "Test data not accessible from validation directory: $(pwd)/../../../test_data/test_data.csv"
                cd - > /dev/null
                continue
            fi
            if [[ ! -f "../../../pretrained_models/$(basename "$model_file")" ]]; then
                print_status "ERROR" "Model file not accessible from validation directory: $(pwd)/../../../pretrained_models/$(basename "$model_file")"
                cd - > /dev/null
                continue
            fi

            print_status "INFO" "Running ml-configurator-cli --convert for $model_name..."

            if ml-configurator-cli --config "${model_name}_config.mtbml" --convert > "${model_name}_validation.log" 2>&1; then
                cd - > /dev/null
                print_status "SUCCESS" "Conversion of $model_name completed successfully"
                
                local metrics_info=$(extract_model_metrics "$validation_log")
                if [[ -n "$metrics_info" ]]; then
                    print_status "INFO" "Model Metrics for $model_name:"
                    echo "$metrics_info"
                fi

                print_status "INFO" "Running ml-configurator-cli --evaluate for $model_name..."
                cd "$validation_dir"
                if ml-configurator-cli --config "${model_name}_config.mtbml" --evaluate >> "${model_name}_validation.log" 2>&1; then
                    cd - > /dev/null
                    print_status "SUCCESS" "Host evaluation of $model_name completed successfully"
                    
                    local validation_metrics=$(extract_validation_metrics "$validation_log")
                    if [[ -n "$validation_metrics" ]]; then
                        print_status "SUCCESS" "Host Validation Results for $model_name:"
                        echo "$validation_metrics"
                    fi

                    if [[ "$enable_target_validation" == "true" ]]; then
                        print_status "INFO" "Attempting target validation for $model_name..."
                        cd "$validation_dir"
                        
                        if check_target_device_available; then
                            if ml-configurator-cli --config "${model_name}_config.mtbml" --target-validate >> "${model_name}_validation.log" 2>&1; then
                                cd - > /dev/null
                                print_status "SUCCESS" "Target validation of $model_name completed successfully"
                                
                                local target_metrics=$(extract_target_validation_metrics "$validation_log")
                                if [[ -n "$target_metrics" ]]; then
                                    print_status "SUCCESS" "Target Validation Results for $model_name:"
                                    echo "$target_metrics"
                                fi
                            else
                                cd - > /dev/null
                                print_status "WARNING" "Target validation of $model_name failed"
                                local target_error_details=$(extract_target_error_details "$validation_log")
                                if [[ -n "$target_error_details" ]]; then
                                    print_status "INFO" "Target validation error details:"
                                    echo -e "${YELLOW}$target_error_details${NC}"
                                fi
                            fi
                        else
                            cd - > /dev/null
                            print_status "WARNING" "Target device not available for validation"
                        fi
                    else
                        print_status "INFO" "Skipping target validation (not enabled)"
                    fi

                else
                    cd - > /dev/null
                    local error_details=$(extract_error_details "$validation_log")
                    
                    if grep -q "Cross-domain validation failed\|FAIL" "${validation_dir}/${model_name}_validation.log"; then
                        print_status "WARNING" "Host evaluation of $model_name failed accuracy requirements - conversion successful"
                        local failed_metrics=$(extract_failed_metrics "$validation_log")
                        if [[ -n "$failed_metrics" ]]; then
                            print_status "ERROR" "Failed Validation Metrics for $model_name:"
                            echo -e "${RED}$failed_metrics${NC}"
                        fi
                    else
                        print_status "WARNING" "Host evaluation of $model_name failed (conversion still successful)"
                        print_status "ERROR" "Error Details:"
                        echo -e "${RED}$error_details${NC}"
                    fi
                fi
                
            else
                cd - > /dev/null
                print_status "ERROR" "Conversion of $model_name failed"
                
                local conv_error_details=$(extract_error_details "$validation_log")
                print_status "ERROR" "Conversion Error Details for $model_name:"
                echo -e "${RED}$conv_error_details${NC}"
            fi

            local model_info="$validation_dir/${model_name}_info.txt"
            echo "=== MODEL INFORMATION FOR $model_name ===" > "$model_info"
            echo "Model file: $model_file" >> "$model_info"
            echo "Config file: $config_file" >> "$model_info"
            echo "Test data: $model_test_data" >> "$model_info"
            echo "File size: $(du -h "$model_file" | cut -f1)" >> "$model_info"
            echo "Test data size: $data_size lines" >> "$model_info"
            echo "Target validation enabled: $enable_target_validation" >> "$model_info"
            echo "Validation date: $(date)" >> "$model_info"
            echo "" >> "$model_info"

            echo "=== VALIDATION RESULTS ===" >> "$model_info"
            
            if grep -q "Model conversion is completed\|Finished ml-coretools model converter successfully" "$validation_log"; then
                echo "STATUS: CONVERSION SUCCESS" >> "$model_info"
                
                if grep -q "Cross-domain validation failed\|FAIL" "$validation_log"; then
                    echo "HOST EVALUATION: FAILED (Accuracy requirements not met)" >> "$model_info"
                elif grep -q "Cross-domain validation passed\|PASS" "$validation_log"; then
                    echo "HOST EVALUATION: SUCCESS" >> "$model_info"
                else
                    echo "HOST EVALUATION: UNKNOWN" >> "$model_info"
                fi

                if [[ "$enable_target_validation" == "true" ]]; then
                    if grep -q "Target validation.*passed\|Target.*validation.*success" "$validation_log"; then
                        echo "TARGET VALIDATION: SUCCESS" >> "$model_info"
                    elif grep -q "Target validation.*failed\|Target.*validation.*fail" "$validation_log"; then
                        echo "TARGET VALIDATION: FAILED" >> "$model_info"
                    else
                        echo "TARGET VALIDATION: NOT PERFORMED (device unavailable or error)" >> "$model_info"
                    fi
                else
                    echo "TARGET VALIDATION: DISABLED" >> "$model_info"
                fi
                
                grep -i "success\|complete\|valid\|info\|model loaded\|generated\|deploy\|convert\|evaluate\|cycles\|memory" "$validation_log" | head -15 >> "$model_info" || true
            else
                echo "STATUS: CONVERSION FAILED" >> "$model_info"
                grep -i "ERROR\|FAIL" "$validation_log" | head -5 >> "$model_info"
            fi

            if ! grep -q "Model conversion is completed\|Finished ml-coretools model converter successfully" "$validation_log"; then
                local error_info="$validation_dir/${model_name}_error.txt"
                echo "=== VALIDATION ERROR FOR $model_name ===" > "$error_info"
                echo "Model file: $model_file" >> "$error_info"
                echo "Config file: $config_file" >> "$error_info"
                echo "Test data: $model_test_data" >> "$error_info"
                echo "Test data size: $data_size lines" >> "$error_info"
                echo "Date: $(date)" >> "$error_info"
                echo "" >> "$error_info"
                echo "=== ERROR LOG ===" >> "$error_info"
                cat "$validation_log" >> "$error_info"
            fi
            
            echo ""
        fi
    done

    create_validation_summary "$validation_dir"
}

check_target_device_available() {
    if command -v wmic &> /dev/null; then
        local usb_devices=$(wmic path Win32_SerialPort where "Description like '%USB%'" get DeviceID /format:list 2>/dev/null | grep "DeviceID=" | wc -l)
        if [[ "$usb_devices" -gt 0 ]]; then
            return 0
        fi
    fi
    
    for port in COM3 COM4 COM5 COM6 COM7 COM8 COM9; do
        if [[ -e "/dev/tty${port: -1}" ]] || [[ -c "/dev/${port}" ]]; then
            return 0
        fi
    done
    
    return 1
}