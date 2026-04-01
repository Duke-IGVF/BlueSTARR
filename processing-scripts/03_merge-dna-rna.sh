#!/usr/bin/env bash

set -euo pipefail

min_count_threshold=100
sample_dna=""
sample_rna=""
window_bp=300
step_bp=50

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

for value_name in min_count_threshold window_bp step_bp; do
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

if (( ${#dna_files[@]} < 3 )); then
    echo "Expected at least 3 DNA bedgraph files, found ${#dna_files[@]}." >&2
    exit 1
fi

if (( ${#rna_files[@]} < 3 )); then
    echo "Expected at least 3 RNA bedgraph files, found ${#rna_files[@]}." >&2
    exit 1
fi

paste -d"\t" \
    "${dna_files[@]}" \
    "${rna_files[@]}" \
| awk -vTHRES="${min_count_threshold}" -vOFS="\t" 'BEGIN{print"chrom\tstart\tend\tinput_rep1\tinput_rep2\tinput_rep3\toutput_rep1\toutput_rep2\toutput_rep3"}($4+$8+$12>THRES) && ($16+$20+$24>THRES){print $1,$2,$3,$4,$8,$12,$16,$20,$24}' \
> "combined.input_and_output.gt_${min_count_threshold}.bdg"