#!/bin/bash
# compareSuite.sh
# Usage: ./compareSuite.sh suite-file program1 program2

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 suite-file program1 program2" >&2
    exit 1
fi

suite_file="$1"
program1="$2"
program2="$3"

# Counters
total_tests=0
passed_tests=0
failed_tests=0
leak_count_p1=0
leak_count_p2=0
leak_tests_p1=()
leak_tests_p2=()
passed_list=()
failed_list=()

echo "=== Running test suite: $suite_file ==="
echo

for stem in $(cat "$suite_file"); do
    ((total_tests++))
    echo "Running test: $stem"

    # Get args if available
    if [ -r "$stem.args" ]; then
        args=$(cat "$stem.args")
    else
        args=""
    fi

    tmp1=$(mktemp)
    tmp2=$(mktemp)
    val1=$(mktemp)
    val2=$(mktemp)

    # Run both programs (optionally with .in input)
    if [ -r "$stem.in" ]; then
        valgrind --leak-check=full --error-exitcode=100 --log-file="$val1" "$program1" $args < "$stem.in" > "$tmp1" 2>/dev/null
        status1=$?
        valgrind --leak-check=full --error-exitcode=100 --log-file="$val2" "$program2" $args < "$stem.in" > "$tmp2" 2>/dev/null
        status2=$?
    else
        valgrind --leak-check=full --error-exitcode=100 --log-file="$val1" "$program1" $args > "$tmp1" 2>/dev/null
        status1=$?
        valgrind --leak-check=full --error-exitcode=100 --log-file="$val2" "$program2" $args > "$tmp2" 2>/dev/null
        status2=$?
    fi

    # Compare outputs
    if diff -q "$tmp1" "$tmp2" > /dev/null; then
        echo "Test passed: $stem"
        ((passed_tests++))
        passed_list+=("$stem")
    else
        echo -e "\e[31mDifference in test: $stem\e[0m"
        ((failed_tests++))
        failed_list+=("$stem")
        echo "Args:"; [ -r "$stem.args" ] && cat "$stem.args"
        echo "Input:"; [ -r "$stem.in" ] && cat "$stem.in"
        echo "--- Program 1 output ---"
        cat "$tmp1"
        echo "--- Program 2 output ---"
        cat "$tmp2"
    fi

    # Check for memory leaks in valgrind logs
    if grep -q "definitely lost: [1-9]" "$val1"; then
        ((leak_count_p1++))
        leak_tests_p1+=("$stem")
        echo "☠️  Memory leak detected in $program1 for test $stem"
    fi

    if grep -q "definitely lost: [1-9]" "$val2"; then
        ((leak_count_p2++))
        leak_tests_p2+=("$stem")
        echo "☠️  Memory leak detected in $program2 for test $stem"
    fi

    rm -f "$tmp1" "$tmp2" "$val1" "$val2"
    echo
done

echo "=== Test Summary ==="
echo "Total tests: $total_tests"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"
echo

echo "=== Memory Leak Summary ==="
echo "$program1 leaks: $leak_count_p1"
if (( leak_count_p1 > 0 )); then
    printf '  - %s\n' "${leak_tests_p1[@]}"
fi
echo
echo "$program2 leaks: $leak_count_p2"
if (( leak_count_p2 > 0 )); then
    printf '  - %s\n' "${leak_tests_p2[@]}"
fi
echo

echo "=== Passed Tests ==="
printf '  - %s\n' "${passed_list[@]}"
echo
if (( failed_tests > 0 )); then
    echo "=== Failed Tests ==="
    printf '  - %s\n' "${failed_list[@]}"
    echo
fi

echo "Complete"
