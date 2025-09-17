#!/bin/bash

# Filter out -G flags from compiler arguments
filtered_args=()
for arg in "$@"; do
    if [[ "$arg" != "-G" && "$arg" != "-G"* ]]; then
        filtered_args+=("$arg")
    fi
done

# Call the actual compiler with filtered arguments
exec clang "${filtered_args[@]}"

