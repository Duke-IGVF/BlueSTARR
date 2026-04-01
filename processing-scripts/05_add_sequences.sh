#!/usr/bin/env bash

set -euo pipefail

input_file=""
min_count_threshold=100
input_dir="."
output_dir=""
genome_file=""

usage() {
    cat <<'EOF'
Usage: 05_add_sequences.sh --genome-file GENOME [--input-file FILE | --min-count-threshold N] [options]

Extract the windows sequences from the given genome file and add them as
a new column to the input count (plus log2FC) table. The file with the
extracted sequences is saved as <input_file_base>.sequences.fa, and the
final output is saved as <input_file_base>.sequence.txt.gz.

Required arguments:
  --genome-file FILE            Reference genome FASTA (.fna/.fa)

Input selection (choose one):
  --input-file FILE             Input log2FC table file
  --min-count-threshold N       Locate input as combined.input_and_output.gt_N.log2FC.txt (default: 100)

Optional arguments:
  --input-dir DIR               Directory for threshold-based input lookup (default: .)
  --output-dir DIR              Directory for outputs (default: input file directory)
  --help                        Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input-file)
            input_file=${2:-}
            shift 2
            ;;
        --min-count-threshold)
            min_count_threshold=${2:-}
            shift 2
            ;;
        --input-dir)
            input_dir=${2:-}
            shift 2
            ;;
        --output-dir)
            output_dir=${2:-}
            shift 2
            ;;
        --genome-file)
            genome_file=${2:-}
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

if [[ -z "$genome_file" ]]; then
    echo "--genome-file is required." >&2
    usage >&2
    exit 1
fi

if [[ -n "$input_file" && "$min_count_threshold" != "100" ]]; then
    echo "Use either --input-file or --min-count-threshold, not both." >&2
    usage >&2
    exit 1
fi

if ! [[ "$min_count_threshold" =~ ^[1-9][0-9]*$ ]]; then
    echo "--min-count-threshold must be a positive integer." >&2
    exit 1
fi

if [[ -n "$input_file" ]]; then
    input_path="$input_file"
else
    input_path="${input_dir}/combined.input_and_output.gt_${min_count_threshold}.log2FC.txt"
fi

if [[ ! -f "$input_path" ]]; then
    echo "Input file not found: $input_path" >&2
    exit 1
fi

if [[ ! -f "$genome_file" ]]; then
    echo "Genome file not found: $genome_file" >&2
    exit 1
fi

input_abs_dir=$(cd "$(dirname "$input_path")" && pwd)
input_base=$(basename "$input_path")
base_no_txt=${input_base%.txt}

if [[ -n "$output_dir" ]]; then
    output_abs_dir="$output_dir"
else
    output_abs_dir="$input_abs_dir"
fi
mkdir -p "$output_abs_dir"

intermediate_file="${output_abs_dir}/${base_no_txt}.sequences.fa"
output_file="${output_abs_dir}/${base_no_txt}.sequence.txt.gz"

tail -n+2 "$input_path" \
| cut -f1-3 \
| bedtools getfasta \
    -fi "$genome_file" \
    -bed stdin \
> "$intermediate_file"

paste -d"\t" "$input_path" \
    <(cat <(echo sequence) <(awk 'NR%2==0' "$intermediate_file")) \
| gzip -c \
> "$output_file"
