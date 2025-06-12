#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"

create_directories() {
    print_status "INFO" "Creating necessary directories..."
    mkdir -p test_results
    print_status "SUCCESS" "Directories created"
}
