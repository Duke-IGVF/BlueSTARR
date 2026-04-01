#!/usr/bin/env python3

import argparse
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compute log2 fold change (RNA/DNA) from combined input/output bedgraph and adds it as a column."
    )
    input_group = parser.add_mutually_exclusive_group(required=True)
    input_group.add_argument(
        "--input-file",
        help="Path to input bedgraph file (e.g., combined.input_and_output.gt_100.bdg)",
    )
    input_group.add_argument(
        "--min-count-threshold",
        type=int,
        default=100,
        help="Minimum count threshold to match file pattern (default: 100)",
    )
    parser.add_argument(
        "--input-dir",
        default=".",
        help="Directory to search for input file when using --min-count-threshold (default: current directory)",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory to write output file (default: same as input file directory)",
    )
    return parser.parse_args()


def find_input_file(
    threshold: int, input_dir: Path
) -> Path:
    pattern = f"combined.input_and_output.gt_{threshold}.bdg"
    matches = list(input_dir.glob(pattern))
    if not matches:
        raise FileNotFoundError(
            f"No file matching pattern '{pattern}' found in {input_dir}"
        )
    if len(matches) > 1:
        raise ValueError(
            f"Multiple files matching pattern '{pattern}' in {input_dir}: {matches}"
        )
    return matches[0]


def main() -> None:
    args = parse_args()

    if args.input_file:
        input_path = Path(args.input_file).resolve()
    else:
        input_dir = Path(args.input_dir).resolve()
        input_path = find_input_file(args.min_count_threshold, input_dir)

    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    output_dir = (
        Path(args.output_dir).resolve()
        if args.output_dir
        else input_path.parent
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    df = pd.read_csv(input_path, sep="\t")
    df = df.astype(int, errors="ignore")
    df.iloc[:, 3:] = df.iloc[:, 3:] / df.iloc[:, 3:].sum() * 1e6

    log2fc_tmp = np.log2(
        (0.001 + df.iloc[:, 6:].mean(axis=1))
        / (0.001 + df.iloc[:, 3:6].mean(axis=1))
    )

    df = pd.read_csv(input_path, sep="\t")
    df = df.astype(int, errors="ignore")
    df["log2FC"] = log2fc_tmp

    output_name = input_path.stem.replace(".bdg", "") + ".log2FC.txt"
    output_path = output_dir / output_name
    df.to_csv(output_path, sep="\t", index=False, float_format="%.5f")


if __name__ == "__main__":
    main()
