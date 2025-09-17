#!/bin/bash

# Comprehensive compiler wrapper that filters out -G flags
# This script intercepts compiler calls and removes problematic flags

# Function to filter arguments
filter_args() {
    local filtered=()
    local skip_next=false
    
    for arg in "$@"; do
        if [[ "$skip_next" == "true" ]]; then
            skip_next=false
            continue
        fi
        
        # Skip -G flag and its argument if it exists
        if [[ "$arg" == "-G" ]]; then
            skip_next=true
            continue
        elif [[ "$arg" == "-G"* ]]; then
            continue
        else
            filtered+=("$arg")
        fi
    done
    
    # Return the filtered arguments as a properly quoted array
    printf '%q ' "${filtered[@]}"
}

# Get the filtered arguments - properly handle spaces in paths
filtered_args_str=$(filter_args "$@")
eval "filtered_args=($filtered_args_str)"

# Determine the actual compiler to use
if [[ "$0" == *"clang"* ]] || [[ "$1" == *"clang"* ]]; then
    COMPILER="clang"
elif [[ "$0" == *"gcc"* ]] || [[ "$1" == *"gcc"* ]]; then
    COMPILER="gcc"
elif [[ "$0" == *"g++"* ]] || [[ "$1" == *"g++"* ]]; then
    COMPILER="g++"
elif [[ "$0" == *"clang++"* ]] || [[ "$1" == *"clang++"* ]]; then
    COMPILER="clang++"
else
    # Default to clang for iOS builds
    COMPILER="clang"
fi

# Find the actual compiler in PATH
COMPILER_PATH=$(which "$COMPILER" 2>/dev/null)
if [[ -z "$COMPILER_PATH" ]]; then
    # Fallback to system clang
    COMPILER_PATH="/usr/bin/clang"
fi

# Execute the compiler with filtered arguments
exec "$COMPILER_PATH" "${filtered_args[@]}"

