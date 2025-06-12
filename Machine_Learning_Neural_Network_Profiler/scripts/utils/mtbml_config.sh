#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"


generate_basic_mtbml_config() {
    local model_file="$1"
    local config_file="$2"
    local model_name="$3"
    local test_data_path="$4"
    local quantization_type="$5"
    
    local model_basename=$(basename "$model_file")
    local model_rel_path="../../../pretrained_models/$model_basename"
    local test_data_rel_path="../../../test_data/test_data.csv"
    
    local feat_count=784
    local target_device="APP_CY8CKIT-062-BLE"
    
    if [[ "$model_name" == *"mnist"* ]]; then
        feat_count=784
    fi
    
    local com_port="auto"
    if command -v wmic &> /dev/null; then
        local detected_port=$(wmic path Win32_SerialPort where "Description like '%USB%'" get DeviceID /format:list 2>/dev/null | grep "DeviceID=" | head -1 | cut -d'=' -f2 | tr -d '\r\n')
        if [[ -n "$detected_port" ]]; then
            com_port="$detected_port"
            print_status "INFO" "Auto-detected COM port: $com_port"
        fi
    fi
    
    print_status "INFO" "Config paths - Model: $model_rel_path, Test data: $test_data_rel_path"
    
    local float32="false"
    local int16x16="false"
    local int16x8="false"
    local int8x8="false"
    local tflm_quantization="FLOAT"
    local nn_type=""
    
    if [[ -z "$quantization_type" ]]; then
        quantization_type="float32"
    fi
    
    case "$quantization_type" in
        "float32")
            float32="true"
            tflm_quantization="FLOAT"
            nn_type="float"
            ;;
        "int16x16")
            int16x16="true"
            tflm_quantization="INT16X16"
            nn_type="int16x16"
            ;;
        "int16x8")
            int16x8="true"
            tflm_quantization="INT16X8"
            nn_type="int16x8"
            ;;
        "int8x8")
            int8x8="true"
            tflm_quantization="INT8X8"
            nn_type="int8x8"
            ;;
        *)
            float32="true"
            tflm_quantization="FLOAT"
            nn_type="float"
            quantization_type="float32"
            ;;
    esac
    
    local makefile_info="$config_file.makefile_params"
    cat > "$makefile_info" << EOF
# Makefile parameters for ${model_name^^}_MODEL
NN_TYPE=$nn_type
NN_MODEL_NAME=${model_name^^}_MODEL
NN_MODEL_FOLDER=mtb_ml_gen
NN_INFERENCE_ENGINE=tflm
EOF

    cat > "$config_file" << EOF
{
    "app": "ML",
    "calibration_data": {
        "active_state": true,
        "feat_col_count": $feat_count,
        "feat_col_first": 1,
        "input_calibration_type": "ML",
        "input_format": "JPEG",
        "path": "$test_data_rel_path",
        "target_col_count": 1,
        "target_col_first": 0
    },
    "filetype": "modustoolbox-ml-configurator",
    "formatVersion": "3",
    "lastSavedWith": "ML Configurator",
    "lastSavedWithVersion": "2.0.0",
    "name": "${model_name^^}_MODEL",
    "model": {
        "framework": "TFLITE",
        "path": "$model_rel_path",
        "optimization_ifx": "SIZE",
        "optimization_tflm": false,
        "quantization": {
            "float32": $float32,
            "int16x16": $int16x16,
            "int16x8": $int16x8,
            "int8x8": $int8x8
        },
        "sparsity_tflm": false,
        "tflm_model_quantization": "$tflm_quantization"
    },
    "target": "$target_device",
    "output_dir": "mtb_ml_gen",
    "toolsPackage": "ModusToolbox Machine Learning Pack 2.0.0",
    "validation": {
        "feat_col_count": $feat_count,
        "feat_col_first": 1,
        "input_format": "JPEG",
        "input_type": "ML",
        "max_samples": 100,
        "path": "$test_data_rel_path",
        "quantization": {
            "float32": true,
            "int16x16": true,
            "int16x8": true,
            "int8x8": true
        },
        "target": {
            "target_quantization": "$quantization_type"
        },
        "target_col_count": 1,
        "target_col_first": 0
    },
    "target_validation": {
        "active_state": false,
        "feat_col_count": $feat_count,
        "feat_col_first": 1,
        "input_format": "JPEG",
        "input_type": "ML",
        "max_samples": 10,
        "path": "$test_data_rel_path",
        "target_col_count": 1,
        "target_col_first": 0,
        "device_settings": {
            "target_device": "$target_device",
            "connection_type": "uart",
            "uart_port": "$com_port",
            "baud_rate": 1000000,
            "timeout": 60,
            "auto_detect": true,
            "retry_count": 3
        }
    }
}
EOF
        
    print_status "SUCCESS" "Generated .mtbml config with $quantization_type quantization: $config_file"
    print_status "INFO" "Makefile parameters saved to: $makefile_info"
    print_status "INFO" "Target model file: $model_basename"
}
