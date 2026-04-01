#!/usr/bin/env python3

import argparse
from pathlib import Path

import pandas as pd


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Find windows shared across all matching bedgraph replicates and "
            "write filtered per-replicate bedgraph files."
        )
    )
    parser.add_argument(
        "--sample",
        required=True,
        help="Sample prefix used to match files like SAMPLE.REP.w300s50.bdg",
    )
    parser.add_argument(
        "--window-bp",
        type=int,
        default=300,
        help="Window length in bp (default: 300)",
    )
    parser.add_argument(
        "--step-bp",
        type=int,
        default=50,
        help="Step size in bp (default: 50)",
    )
    parser.add_argument(
        "--input-dir",
        default=".",
        help="Directory containing input .bdg files (default: current directory)",
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory to write filtered output files (default: same as input-dir)",
    )
    return parser.parse_args()


def read_bedgraph(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", names=["chrom", "start", "end", "count"])
    df.index = (
        df["chrom"]
        + "_"
        + df["start"].astype(str)
        + "_"
        + df["end"].astype(str)
    )
    return df


def main() -> None:
    args = parse_args()

    if args.window_bp <= 0:
        raise ValueError("--window-bp must be a positive integer")
    if args.step_bp <= 0:
        raise ValueError("--step-bp must be a positive integer")

    input_dir = Path(args.input_dir).resolve()
    output_dir = Path(args.output_dir).resolve() if args.output_dir else input_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    suffix = f".w{args.window_bp}s{args.step_bp}.bdg"
    pattern = f"{args.sample}.*{suffix}"
    bedgraphs = sorted(input_dir.glob(pattern))

    if not bedgraphs:
        raise FileNotFoundError(
            f"No files matched pattern '{pattern}' in {input_dir}"
        )

    common_index = read_bedgraph(bedgraphs[0]).index
    for path in bedgraphs[1:]:
        df_tmp = read_bedgraph(path)
        common_index = common_index.join(df_tmp.index, how="inner")

    for path in bedgraphs:
        df_tmp = read_bedgraph(path)
        filtered = df_tmp.join(pd.DataFrame(index=common_index), how="inner")
        output_name = path.name.replace(
            suffix, f".w{args.window_bp}s{args.step_bp}.in_common_win.bdg"
        )
        filtered.to_csv(output_dir / output_name, sep="\t", index=False)


if __name__ == "__main__":
    main()