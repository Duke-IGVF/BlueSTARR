#!/usr/bin/env bash

set -euo pipefail

sample=""
rep=""
window_bp=300
step_bp=50

usage() {
    cat <<'EOF'
Usage: 01_avg-coverage-per-window.sh --sample SAMPLE --rep REP [--window-bp BP] [--step-bp BP]

Summarizes whole-genome STARR-seq input (DNA) and output (RNA) data in
overlapping windows (by default 300bp length, with50bp step). Uses the
bwtool command-line tool to extract counts per window and awk to compute
the average coverage per window.

Required arguments:
  --sample       Sample name used in the input/output file names
  --rep          Replicate name used in the input/output file names

Optional arguments:
  --window-bp    Window length in bp (default: 300)
  --step-bp      Step size in bp (default: 50)
  --help         Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample)
            sample=${2:-}
            shift 2
            ;;
        --rep)
            rep=${2:-}
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

if [[ -z "$sample" || -z "$rep" ]]; then
    echo "Both --sample and --rep are required." >&2
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

input_file="${sample}.${rep}.bw"
output_file="${sample}.${rep}.w${window_bp}s${step_bp}.bdg"

if [[ ! -f "$input_file" ]]; then
    echo "Input file not found: $input_file" >&2
    exit 1
fi

bwtool window "$window_bp" \
    "$input_file" \
    "-step=${step_bp}" \
    -skip-NA \
| awk -vOFS="\t" 'NR==1{ split($4, vv,","); nwins=length(vv)}{tot=0; split($4, vv,","); for (ii=1; ii<=nwins; ii+=1){tot+=vv[ii]} print $1,$2,$3,tot/nwins}' \
| awk '$4!=0' \
> "$output_file"