#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
Purple='\033[0;35m'
Cyan='\033[0;36m'
NC='\033[0m'

print_status() {
    local status="$1"
    local message="$2"
    case $status in
        "SUCCESS") echo -e "${GREEN} $message${NC}" ;;
        "ERROR") echo -e "${RED} $message${NC}" ;;
        "WARNING") echo -e "${YELLOW} $message${NC}" ;;
        "INFO") echo -e "${BLUE} $message${NC}" ;;
        "COMMANDS") echo -e "${Cyan} $message${NC}" ;;
        "START") echo -e "${Purple}=== $message ===${NC}" ;;
    esac
}
