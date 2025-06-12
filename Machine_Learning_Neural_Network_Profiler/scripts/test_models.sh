#!/bin/bash

set -e

source "$(dirname "${BASH_SOURCE[0]}")/utils/colors.sh"
source "$(dirname "${BASH_SOURCE[0]}")/utils/dependencies.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validation/model_tester.sh"

main() {
    local enable_target_validation=true
    local quantization_type="int8x8"
    
    if [[ "$1" == "--help" ]]; then
        print_status "INFO" "This script tests existing models from the ../pretrained_models directory."
        print_status "INFO" "Models should be in .h5 or .tflite format with corresponding .mtbml config (generates automatically) files."
        print_status "INFO" "It will also validate models using ModusToolbox ML Configurator and generate a summary report."
        print_status "INFO" "By default, the script will:
         - target device is set to APP_CY8CKIT-062-BLE
         - test data is set to ../../../test_data/test_data.csv
         - models file path is set to ../../../pretrained_models (use all .h5 and .tflite files)
         - feature count is set to 784 (for MNIST models)
         - COM port is auto-detected if available
         - .mtbml config files are generated with INT8x8 quantization and target validation enabled
         - test results are stored in the test_results directory
        "

        print_status "COMMANDS" "Usage: $0 
            [--help] - list available options 
            [--force] - force re-testing of models (it will re-generate .mtbml config files)
            [--enable-target] - enable target device validation
            [--quantization TYPE] - set quantization type (float32, int16x16, int16x8, int8x8) [default: int8x8]
            [--clean] - clean up test results directory

        print_status "INFO" "Example: $0 --force --enable-target APP_CY8CKIT-062-BLE --quantization int16x8"
        "

        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean)
                print_status "INFO" "Cleaning up test results directory..."
                rm -rf test_results/*
                print_status "SUCCESS" "Test results directory cleaned"
                exit 0
                ;;
            --force)
                print_status "INFO" "Forcing re-testing of models..."
                enable_target_validation=true
                shift
                ;;
            --enable-target)
                if [[ "$2" == "$target_device" ]]; then
                    print_status "ERROR" "Target device validation is already enabled for $target_device"
                    exit 1
                fi
                print_status "INFO" "Enabling target device validation..."
                enable_target_validation=true
                shift
                ;;
            --quantization)
                quantization_type="$2"
                if [[ ! "$quantization_type" =~ ^(float32|int16x16|int16x8|int8x8)$ ]]; then
                    print_status "ERROR" "Invalid quantization type: $quantization_type. Valid options: float32, int16x16, int16x8, int8x8"
                    exit 1
                fi
                print_status "INFO" "Using quantization type: $quantization_type"
                shift 2
                ;;
            *)
                print_status "ERROR" "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done

    print_status "START" "=== STARTING ML MODEL TESTING ==="

    create_directories

    if [[ ! -d "../pretrained_models" ]]; then
        print_status "ERROR" "../pretrained_models directory not found"
        exit 1
    fi

    if [[ -z "$(find ../pretrained_models -name '*.h5' -o -name '*.tflite' 2>/dev/null)" ]]; then
        print_status "ERROR" "No .h5 or .tflite models found in ../pretrained_models"
        exit 1
    fi

    print_status "SUCCESS" "Found existing models in ../pretrained_models directory"

    if ! test_models "$enable_target_validation" "$quantization_type"; then
        print_status "ERROR" "Model testing failed"
        exit 1
    fi

    print_status "SUCCESS" "Model testing completed successfully!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi