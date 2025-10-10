#!/bin/bash
# Jerry Wu
# compareSuite.sh
# Usage: ./compareSuite.sh suite-file program1 program2

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 suite-file program1 program2" >&2
    exit 1
fi

suite_file="$1"
program1="$2"
program2="$3"

for stem in $(cat "$suite_file"); do
    # Get args if available
    if [ -r "$stem.args" ]; then
        args=$(cat "$stem.args")
    else
        args=""
    fi

    # Run both programs with optional .in input
    tmp1=$(mktemp)
    tmp2=$(mktemp)

    if [ -r "$stem.in" ]; then
        $program1 $args < "$stem.in" > "$tmp1"
        $program2 $args < "$stem.in" > "$tmp2"
    else
        $program1 $args > "$tmp1"
        $program2 $args > "$tmp2"
    fi

    # Compare results
    if ! diff "$tmp1" "$tmp2" > /dev/null; then
        echo "Difference in test: $stem"
        echo "Args:"
        if [ -r "$stem.args" ]; then cat "$stem.args"; fi
        echo "Input:"
        if [ -r "$stem.in" ]; then cat "$stem.in"; fi
        echo "--- Program 1 output ---"
        cat "$tmp1"
        echo "--- Program 2 output ---"
        cat "$tmp2"
        echo
    else
        echo "Test passed: $stem"
    fi

    rm "$tmp1" "$tmp2"
done
