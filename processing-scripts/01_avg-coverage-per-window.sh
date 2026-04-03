#!/usr/bin/env bash

set -euo pipefail

input_file=""
output_dir=""
window_bp=300
step_bp=50

usage() {
    cat <<'EOF'
Usage: 01_avg-coverage-per-window.sh [--output-dir DIR] [--window-bp BP] [--step-bp BP] INPUT_FILE

Summarizes whole-genome STARR-seq input (DNA) and output (RNA) data in
overlapping windows (by default 300bp length, with50bp step). Uses the
bwtool command-line tool to extract counts per window and awk to compute
the average coverage per window.

Required arguments:
    INPUT_FILE     Input bigWig file (for example: sample.rep.bw)

Optional arguments:
  --output-dir   Directory for output file (default: input file directory)
  --window-bp    Window length in bp (default: 300)
  --step-bp      Step size in bp (default: 50)
  --help         Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-dir)
            output_dir=${2:-}
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
        --*)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ -n "$input_file" ]]; then
                echo "Only one input file may be provided." >&2
                usage >&2
                exit 1
            fi
            input_file=$1
            shift
            ;;
    esac
done

if [[ -z "$input_file" ]]; then
    echo "An input file is required." >&2
    usage >&2
    exit 1
fi

if ! [[ "$window_bp" =~ ^[1-9][0-9]*$ ]]; then
    echo "--window-bp must be a positive integer." >&2
    exit 1
fi

if ! [[ "$step_bp" =~ ^[1-9][0-9]*$ ]]; then
    echo "--step-bp must be a positive integer." >&2
    exit 1
fi

if [[ ! -f "$input_file" ]]; then
    echo "Input file not found: $input_file" >&2
    exit 1
fi

input_dir=$(dirname "$input_file")
input_name=$(basename "$input_file")

if [[ -z "$output_dir" ]]; then
    output_dir="$input_dir"
fi

if [[ ! -d "$output_dir" ]]; then
    echo "Output directory not found: $output_dir" >&2
    exit 1
fi

if [[ "$input_name" == *.* ]]; then
    input_ext=".${input_name##*.}"
    input_stem="${input_name%.*}"
else
    input_ext=""
    input_stem="$input_name"
fi

if [[ "$input_ext" != ".bw" ]]; then
    echo "Warning: input file extension is '$input_ext' (expected '.bw')." >&2
fi

output_file="$output_dir/${input_stem}.w${window_bp}s${step_bp}.bdg"

bwtool window "$window_bp" \
    "$input_file" \
    "-step=${step_bp}" \
    -skip-NA \
| awk -vOFS="\t" 'NR==1{ split($4, vv,","); nwins=length(vv)}{tot=0; split($4, vv,","); for (ii=1; ii<=nwins; ii+=1){tot+=vv[ii]} print $1,$2,$3,tot/nwins}' \
| awk '$4!=0' \
> "$output_file"