#!/bin/bash
# Test runner script for Catch Me If You Can
# Usage: ./run_tests.sh [options]
#
# Options:
#   --verbose, -v    Show verbose output
#   --quick, -q      Run quick test configuration
#   --ci             Run CI test configuration (TAP output)
#   --file FILE      Run specific test file
#   --help, -h       Show this help message

set -e

# Change to project directory
cd "$(dirname "$0")"

# Default configuration
CONFIG="default"
VERBOSE=""
FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="--verbose"
            shift
            ;;
        -q|--quick)
            CONFIG="quick"
            shift
            ;;
        --ci)
            CONFIG="ci"
            shift
            ;;
        --file)
            FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Catch Me If You Can Test Runner"
            echo ""
            echo "Usage: ./run_tests.sh [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v    Show verbose output"
            echo "  --quick, -q      Run quick test configuration"
            echo "  --ci             Run CI test configuration (TAP output)"
            echo "  --file FILE      Run specific test file"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./run_tests.sh                           # Run all tests"
            echo "  ./run_tests.sh --verbose                 # Run with verbose output"
            echo "  ./run_tests.sh --file tests/shared/Constants_spec.lua"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if busted is installed
if ! command -v busted &> /dev/null; then
    echo "Error: busted is not installed"
    echo ""
    echo "Install with:"
    echo "  brew install lua luarocks  # macOS"
    echo "  luarocks install busted"
    echo ""
    echo "Or on Windows:"
    echo "  choco install lua"
    echo "  luarocks install busted"
    exit 1
fi

# Run tests
echo "Running Catch Me If You Can Tests"
echo "================================="
echo ""

if [ -n "$FILE" ]; then
    # Run specific file
    echo "Running: $FILE"
    busted --helper=tests/init.lua $VERBOSE "$FILE"
else
    # Run all tests with configuration
    echo "Configuration: $CONFIG"
    busted --run=$CONFIG $VERBOSE
fi

echo ""
echo "Tests completed!"
