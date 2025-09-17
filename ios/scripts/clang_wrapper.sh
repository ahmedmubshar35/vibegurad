#!/bin/bash
# Wrapper script to filter out unsupported -G flag from clang compiler calls

# Get the actual compiler path
COMPILER="/usr/bin/clang"

# Filter out -G flags from arguments
FILTERED_ARGS=()
SKIP_NEXT=false

for arg in "$@"; do
    if [ "$SKIP_NEXT" = true ]; then
        SKIP_NEXT=false
        continue
    fi

    if [[ "$arg" == "-G" ]]; then
        SKIP_NEXT=true
        continue
    fi

    if [[ "$arg" == -G* ]]; then
        continue
    fi

    FILTERED_ARGS+=("$arg")
done

# Execute the compiler with filtered arguments
exec "$COMPILER" "${FILTERED_ARGS[@]}"