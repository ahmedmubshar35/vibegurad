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
    
    printf '%s\n' "${filtered[@]}"
}

# Get the filtered arguments
filtered_args=($(filter_args "$@"))

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

# Execute the compiler with filtered arguments
exec "$COMPILER" "${filtered_args[@]}"

