#!/usr/bin/env python3

import argparse
import csv
import gzip
import re
from pathlib import Path
from typing import Iterator, TextIO


_STRIPPABLE_EXTENSIONS = (".gz", ".txt", ".sequence", ".log2FC")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Split a sequence-augmented BlueSTARR TSV table into a FASTA file "
            "and a DNA and RNA counts table."
        )
    )
    parser.add_argument(
        "--input-file",
        required=True,
        help="Input TSV file, optionally gzip-compressed (.gz)",
    )
    parser.add_argument(
        "--fasta-output",
        default=None,
        help="Output FASTA path (default: <input-base>.fasta.gz in the output directory)",
    )
    parser.add_argument(
        "--counts-output",
        default=None,
        help=(
            "Output counts table path "
            "(default: <input-base>.counts.txt.gz in the output directory)"
        ),
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Directory for default outputs (default: input file directory)",
    )
    parser.add_argument(
        "--wrap-length",
        type=int,
        default=60,
        help="Sequence line length in FASTA output (default: 60)",
    )
    parser.add_argument(
        "--dna-prefix",
        default="input_",
        help="Column name prefix for DNA replicate columns (default: input_)",
    )
    parser.add_argument(
        "--rna-prefix",
        default="output_",
        help="Column name prefix for RNA replicate columns (default: output_)",
    )
    parser.add_argument(
        "--output-base",
        default=None,
        help=(
            "Base name for default output files, overriding the name derived from "
            "the input file (default: derived from input file name)"
        ),
    )
    return parser.parse_args()


def open_maybe_gzip(path: Path) -> TextIO:
    if path.suffix == ".gz":
        return gzip.open(path, "rt", newline="")
    return path.open("r", newline="")


def infer_output_base(input_path: Path) -> str:
    name = input_path.name
    changed = True
    while changed:
        changed = False
        for ext in _STRIPPABLE_EXTENSIONS:
            if name.endswith(ext):
                name = name[: -len(ext)]
                changed = True
    return name


def get_replicate_columns(
    header: list[str], dna_prefix: str, rna_prefix: str
) -> tuple[list[int], list[int]]:
    dna_pattern = re.compile(re.escape(dna_prefix) + r"rep[1-9]")
    rna_pattern = re.compile(re.escape(rna_prefix) + r"rep[1-9]")
    dna_columns = [
        index for index, name in enumerate(header) if dna_pattern.fullmatch(name)
    ]
    rna_columns = [
        index for index, name in enumerate(header) if rna_pattern.fullmatch(name)
    ]

    if not dna_columns:
        raise ValueError(
            f"No DNA replicate columns matching '{dna_prefix}repN' were found."
        )
    if not rna_columns:
        raise ValueError(
            f"No RNA replicate columns matching '{rna_prefix}repN' were found."
        )

    expected_dna_columns = list(range(3, 3 + len(dna_columns)))
    if dna_columns != expected_dna_columns:
        raise ValueError(
            "DNA replicate columns must start at column 4 and be contiguous."
        )

    expected_rna_columns = list(
        range(3 + len(dna_columns), 3 + len(dna_columns) + len(rna_columns))
    )
    if rna_columns != expected_rna_columns:
        raise ValueError(
            "RNA replicate columns must immediately follow the DNA replicate columns."
        )

    return dna_columns, rna_columns


def wrap_sequence(sequence: str, wrap_length: int) -> Iterator[str]:
    for start in range(0, len(sequence), wrap_length):
        yield sequence[start : start + wrap_length]


def main() -> None:
    args = parse_args()

    if args.wrap_length <= 0:
        raise ValueError("--wrap-length must be a positive integer")

    input_path = Path(args.input_file).resolve()
    if not input_path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    output_dir = Path(args.output_dir).resolve() if args.output_dir else input_path.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    output_base = args.output_base if args.output_base else infer_output_base(input_path)
    fasta_path = (
        Path(args.fasta_output).resolve()
        if args.fasta_output
        else output_dir / f"{output_base}.fasta.gz"
    )
    counts_path = (
        Path(args.counts_output).resolve()
        if args.counts_output
        else output_dir / f"{output_base}.counts.txt.gz"
    )

    with open_maybe_gzip(input_path) as input_handle:
        reader = csv.reader(input_handle, delimiter="\t")
        header = next(reader, None)
        if header is None:
            raise ValueError("Input file is empty.")

        if header[:3] != ["chrom", "start", "end"]:
            raise ValueError(
                "The first three columns must be named chrom, start, and end."
            )

        dna_columns, rna_columns = get_replicate_columns(header, args.dna_prefix, args.rna_prefix)
        expected_min_col_count = 3 + len(dna_columns) + len(rna_columns) + 1
        if len(header) < expected_min_col_count:
            raise ValueError(
                "Expected at least columns chrom/start/end, DNA replicates, RNA replicates, "
                "and one sequence column."
            )

        sequence_index = len(header) - 1
        counts_columns = dna_columns + rna_columns

        with gzip.open(fasta_path, "wt", newline="") as fasta_handle, gzip.open(
            counts_path, "wt", newline=""
        ) as counts_handle:
            counts_handle.write(f"DNA={len(dna_columns)}\tRNA={len(rna_columns)}\n")
            counts_writer = csv.writer(counts_handle, delimiter="\t", lineterminator="\n")

            for row_index, row in enumerate(reader):
                sequence = row[sequence_index].strip()
                fasta_handle.write(
                    f">{row_index} /coord={row[0]}:{row[1]}-{row[2]}\n"
                )
                for chunk in wrap_sequence(sequence, args.wrap_length):
                    fasta_handle.write(f"{chunk}\n")

                counts_writer.writerow([row[index] for index in counts_columns])


if __name__ == "__main__":
    main()