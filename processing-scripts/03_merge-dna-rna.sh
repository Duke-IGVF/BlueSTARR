#!/usr/bin/env bash

set -euo pipefail

min_count_threshold=100
sample_dna=""
sample_rna=""
window_bp=300
step_bp=50
num_input_reps=3
num_output_reps=3

usage() {
    cat <<'EOF'
Usage: 03_merge-dna-rna.sh --sample-dna NAME --sample-rna NAME [options]

Merge across DNA and RNA samples and replicates, selecting only windows with
enough counts summed over replicates.

Required arguments:
  --sample-dna NAME             DNA sample prefix
  --sample-rna NAME             RNA sample prefix

Sample prefixes are as in <SAMPLE_DNA>.*.w300s50.in_common_win.bdg.

Optional arguments:
  --min-count-threshold VALUE   Minimum summed-count threshold (default: 100)
  --num-input-reps VALUE        Number of DNA (input) replicates (default: 3)
  --num-output-reps VALUE       Number of RNA (output) replicates (default: 3)
  --window-bp VALUE             Window length in bp (default: 300)
  --step-bp VALUE               Step size in bp (default: 50)
  --help                        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --min-count-threshold)
            min_count_threshold=${2:-}
            shift 2
            ;;
        --num-input-reps)
            num_input_reps=${2:-}
            shift 2
            ;;
        --num-output-reps)
            num_output_reps=${2:-}
            shift 2
            ;;
        --sample-dna)
            sample_dna=${2:-}
            shift 2
            ;;
        --sample-rna)
            sample_rna=${2:-}
            shift 2
            ;;
        --window-bp)
            window_bp=${2:-}
            shift 2
            ;;
        --step-bp)
            step_bp=${2:-}
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$sample_dna" || -z "$sample_rna" ]]; then
    echo "Both --sample-dna and --sample-rna are required." >&2
    usage >&2
    exit 1
fi

for value_name in min_count_threshold window_bp step_bp num_input_reps num_output_reps; do
    value=${!value_name}
    if ! [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
        echo "${value_name} must be a positive integer." >&2
        exit 1
    fi
done

shopt -s nullglob
dna_files=("${sample_dna}".*.w"${window_bp}"s"${step_bp}".in_common_win.bdg)
rna_files=("${sample_rna}".*.w"${window_bp}"s"${step_bp}".in_common_win.bdg)
shopt -u nullglob

if (( ${#dna_files[@]} != num_input_reps )); then
    echo "Expected ${num_input_reps} DNA bedgraph files, found ${#dna_files[@]}." >&2
    exit 1
fi

if (( ${#rna_files[@]} != num_output_reps )); then
    echo "Expected ${num_output_reps} RNA bedgraph files, found ${#rna_files[@]}." >&2
    exit 1
fi

# Build header and awk logic dynamically based on replicate counts.
# Requires all input .bdg files to have identical row order (guaranteed by step 02).
#
# The goal is to build strings that get interpolated into an awk command, since
# the number of replicates isn't known at write time.
#
# The paste command horizontally joins all .bdg files into one wide table. Each
# file contributes 4 columns: chrom, start, end, count. So with 3 DNA reps the
# layout is:
#
#   col 1  col 2  col 3  col 4  col 5  col 6  col 7  col 8  col 9  col 10 col 11 col 12 ...
#   chrom  start  end    dna1   chrom  start  end    dna2   chrom  start  end    dna3   ...
#
# The count for DNA rep i is always at column 4*i (rep 1 -> col 4, rep 2 -> col 8,
# rep 3 -> col 12). RNA rep j follows after all DNA files, so it's at column
# 4*(num_input_reps + j).
#
# The loops build two strings for each group -- a sum expression and a column list:
#
#   # After the loop with num_input_reps=3:
#   awk_dna_sum  = "$4+$8+$12"    # used in the filter condition
#   awk_dna_cols = "$4,$8,$12"    # used in the print statement
#
# The +='$'"${col}"'+' syntax is careful quoting to get a literal $4+ appended
# (the $ must be single-quoted so bash doesn't expand it as a variable). Then
# ${awk_dna_sum%+} strips the trailing + left over from the last iteration.
#
# The end result for num_input_reps=3, num_output_reps=3 is equivalent to the
# original hardcoded awk:
#
#   ($4+$8+$12 > THRES) && ($16+$20+$24 > THRES) { print $1,$2,$3,$4,$8,$12,$16,$20,$24 }
header="chrom\tstart\tend"
for (( i=1; i<=num_input_reps; i++ )); do header+="\tinput_rep${i}"; done
for (( j=1; j<=num_output_reps; j++ )); do header+="\toutput_rep${j}"; done

awk_dna_sum=""
awk_dna_cols=""
for (( i=1; i<=num_input_reps; i++ )); do
    col=$(( 4 * i ))
    awk_dna_sum+='$'"${col}"'+'
    awk_dna_cols+='$'"${col}"','
done
awk_dna_sum="${awk_dna_sum%+}"
awk_dna_cols="${awk_dna_cols%,}"

awk_rna_sum=""
awk_rna_cols=""
for (( j=1; j<=num_output_reps; j++ )); do
    col=$(( 4 * (num_input_reps + j) ))
    awk_rna_sum+='$'"${col}"'+'
    awk_rna_cols+='$'"${col}"','
done
awk_rna_sum="${awk_rna_sum%+}"
awk_rna_cols="${awk_rna_cols%,}"

paste -d"\t" \
    "${dna_files[@]}" \
    "${rna_files[@]}" \
| awk -vTHRES="${min_count_threshold}" -vOFS="\t" \
    'BEGIN{print "'"${header}"'"}
     ('"${awk_dna_sum}"'>THRES) && ('"${awk_rna_sum}"'>THRES){print $1,$2,$3,'"${awk_dna_cols}"','"${awk_rna_cols}"'}' \
> "combined.input_and_output.gt_${min_count_threshold}.bdg"