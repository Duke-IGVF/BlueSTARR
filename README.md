[![DOI](https://zenodo.org/badge/801252410.svg)](https://zenodo.org/badge/latestdoi/801252410)

# BlueSTARR: predicting regulatory effects of non-coding variants

BlueSTARR uses deep-learning for predicting regulatory activation (or suppression) from 300, 600, and 1k base-long genomic non-coding sequences. The BlueSTARR model is trained on the expression activation observed in STARR-seq experiments, a type of high-throughput reporter assay. The quantitative activation signal for training is estimated from RNA over DNA read count ratios.

The architecture of the deep-learning model is fully configurable. See paper for evaluation of different architectures and hyperparameters.

## Running BlueSTARR

Running the BlueSTARR code requires Python 3.10+ and the presence of a number of dependencies. These can be installed locally in the form of a conda environment, or alternatively use the Docker container automatically built and updated for the codebase.

### Pretrained models for inference

Pretrained BlueSTARR models are available from Hugging Face under [majoroslab/BlueSTARR](https://huggingface.co/majoroslab/BlueSTARR).

### Conda Environment Setup

#### Creating a conda environment from scratch

1. Create a new conda environment with Python 3.10. (Later versions may work but have not been tested.)
   ```bash
   # you can also use -n YourEnvName instead of -p /path/to/env
   conda create -p /path/to/new/conda/env -c conda-forge python=3.11
   ```
2. Activate the conda environment you just created:
   ```bash
   conda activate /path/to/new/conda/env
   ```
3. Install the python dependencies using `pip`:
   ```bash
   pip install -r requirements.txt
   ```
   This assumes that you have the repository checked out and are issuing this command from the repo's root directory.
   You can also do this without the full repository; all that's needed is the following two files:
   - [`requirements.txt`](requirements.txt)
   - [`non-tensorflow-reqs.txt`](non-tensorflow-reqs.txt)

#### (Alternative) Cloning a previously exported conda environment

You can “clone” (install every dependency and package at the exact same version, whether there’s a more recent compatible one or not) an existing conda environment by first exporting the configuration of an existing one (either specify it using -n/--name or -p/--prefix, or activate it first) into a file like so:
```
conda env export > /path/to/environment.yml
```
The [`environment.yml`](environment.yml) in this repository was created in this way. To recreate a conda environment from it, do the following:
```
conda env create -p /path/to/new/env -f environment.yml
```
This is not yet a complete environment because the code in this repository depends on some components of a collection of utility classes created by the Majoros lab in the past. To installl these, issue the following command (**after** you activated the conda environment you created in the previous step):
```bash
pip install "git+https://github.com/Duke-GCB/majoros-python-utils.git"
```

_**Caveat:** Although this used to result in a working conda environment at least with conda v4.x (which is fairly old at this point), the conda version provided by a more modern miniconda (which can also be user-installed on an HPC) apparently now fails at successfully creating the environment with this approach. Consider using the from-scratch method._

### Using the Docker Container

A Docker container image is automatically built and updated from the [provided Dockerfile](Dockerfile) when the code in this repository changes or a new release is created.

The container images are [available from the GitHub package registry](https://github.com/Duke-IGVF/BlueSTARR/pkgs/container/bluestarr). Available tags (latest, as well as major, minor and patch releases) and the command for pulling the container image can be found there.

### Fixing TensorRT not found issue

If your system supports TensorRT, it should be installed automatically as a dependency of `tensorflow[and-cuda]`. 

If TensorRT is installed (you can try `import tensorrt` and `import tensorrt_libs` in a Python shell; be sure to have the environment created above activated) and yet Tensorflow reports not finding it, this is likely because of a failure to load the TensorRT libraries. There are different potential causes for this:

- The location of the libraries is not among the directories where dynamic libraries are loaded from. You can fix this by sourcing the [tensorrt-libloc.sh](tensorrt-libloc.sh) script in this repository **before** launching Python (but **after** activating your conda environment), like so:
  ```
  # or use . as shorthand for source
  source tensorrt-libloc.sh
  ```

- The TensorRT libraries are not all provided with the full version (but, for example, only their major version), and Tensorflow looks for them by their full version. To fix this, run the script [tensorrt-fix.sh](tensorrt-fix.sh) (**after** activating your coda environment):
  ```
  bash tensorrt-fix.sh
  ```
  You need to do this only _once_ for a given conda environment.

## Preparing Input Data for Training BlueSTARR

The BlueSTARR model is trained on STARR-seq data, specifically DNA and RNA read counts. Typically these are obtained from the experiment in the form of [FASTQ](https://en.wikipedia.org/wiki/FASTQ_format). The FASTQ files are first converted to [BigWig](https://genome.ucsc.edu/goldenpath/help/bigWig.html) format, and then in several aggregation and filtering steps to the count tables.

### Processing STARR-seq FASTQ files to BigWig format

To process FASTQ files into BigWig files, we use the [STARR-seq_pipeline](https://github.com/ReddyLab/cwl-pipelines/tree/main/v1.0/STARR-seq_pipeline) defined in [Common Workflow Language](https://www.commonwl.org) (CWL).

To execute CWL workflows, you will need a CWL engine, for example [`cwltool`](https://www.commonwl.org/user_guide/introduction/prerequisites.html#cwl-runner).

### Processing STARR-seq BigWig files to count data and FASTA sequences

The STARR-seq BigWig files resulting from the previous step can be transformed to the  BlueSTARR training input table format of DNA and RNA replicate counts per sequence bin through the scripts in the [`processing-scripts`](processing-scripts) directory, following the order indicated by the numeric prefix:

1. `01_avg-coverage-per-window.sh`: Summarizes STARR-seq input (DNA) and output (RNA) data in BigWig files by overlapping windows (by default 300bp length, with50bp step). Outputs bedgraph format.
2. `02_filter-common-windows.py`: Finds windows shared across all matching bedgraph replicates and writes filtered per-replicate bedgraph files.
3. `03_merge-dna-rna.sh`: Merges across DNA and RNA samples and replicates, selecting only windows with enough counts summed over replicates. Outputs bedgraph format.
4. `04_compute-log2fc.py`: Computes log2 fold change (RNA/DNA) from combined input/output bedgraph and adds it as a column. (This is optional.)
5. `05_add_sequences.sh`: Extracts the windows' sequences from a reference genome and adds them as a new column to the counts (plus log2FC) table.
6. `06_split_fasta_and_counts.py`: Splits the sequence-augmented table into a FASTA file and a separate DNA/RNA replicate counts table.

Each of these scripts accepts a `--help` command-line argument to print usage information.

**Dependencies**: Script 02 requires Python 3 with Pandas installed. Script 04 requires Python 3 with NumPy and Pandas installed. Script 06 requires only Python 3. Script 05 requires [bedtools](https://bedtools.readthedocs.io/en/latest/), and script 01 requires [bwtool](https://github.com/CRG-Barcelona/bwtool). If compiling bwtool from source runs into a compile time error, follow [the instructions reported here](https://github.com/CRG-Barcelona/bwtool/issues/49#issuecomment-698980749).

### Removing paralogous sequences

Sequences in the training set that are paralogous (highly similar) to sequences in the validation and test sets can lead to data leakage (and thus an overestimation of trained model accuracy). To reduce the potential for data leakage, paralogous sequences need to be identified and removed.

We used BLASTN to identify sequences with at least 100 consecutive bases in common and greater than 90% sequence identity:

- Build the blast database from all sequences:
  ```
  makeblastdb -in <input-fasta> -dbtype nucl -out <blast-database> -hash_index
  ```
- Query sequences against database:
  ```
  blastn -query <input-fasta> -db <blast-database> -out <output-alignmnt-table> \
         -evalue 1e-5 -outfmt 6 -sum_stats true -perc_identity 90.0 -word_size 100
  ```
- Process the resulting alignment table to create table of paralogous sequence pairs: see script [`clean_all_aligned.py` in BlueSTARR_Evaluation_K562](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_K562/blob/main/leave-one-out/BlueSTARR/leave-one-out/clean_all_aligned.py)
- Use table of paralogous sequence pairs to remove paralogous sequence pairs (along with those matching an [MPRA dataset](https://doi.org/10.1038/s41467-019-11526-w) used for accuracy evaluation) from training data: see script [`remove_paralogs.py` in BlueSTARR_Evaluation_K562](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_K562/blob/main/leave-one-out/BlueSTARR/leave-one-out/remove_paralogs.py).

### Downsampling

In its current implementation, the BlueSTARR training code loads the full dataset into memory prior to commencing the model training loop.  If this requires more memory than available by your compute resources, you can downsample the dataset.

We employ two downsampling strategies that differ in the acceptance probability for each record of counts (= each training sequence):

- **Unbiased downsampling:** each sequence is accepted with a fixed probability _N/M_, where _N_ is the desired sample size and _M_ is the total number of records being sampled. See the script [`downsample-nonuniform.py`](downsample-nonuniform.py), and the script [`downsample-nonuniform-discarded.py` in BlueSTARR_Evaluation_K562](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_K562/blob/main/leave-one-out/BlueSTARR/leave-one-out/downsampling/downsample-nonuniform-discarded.py) for generating the test set from records not accepted into the training data.
- **Biased downsampling:** the acceptance probability is a function of the estimated frequency (or kernel density) distribution of the observed activation signal $\theta$ (RNA over DNA).
    * The script [`downsample.py`](downsample.py) uses the empirical histogram-based PDF, where the acceptance probability for a record is $\min(1, N/(M B p_i))$, where $p_i$ is the observed proportion of records in histogram bin $i$ ($i \in \\{1,\ldots,B\\}$) into which the observed value of $\theta$ falls.
    * The script [`downsample-biased.py` in BlueSTARR_Evaluation_A549](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_A549/blob/main/full-set/BlueSTARR/downsample-biased.py) implements other functions, including PDFs and CDFs of lognormal distributions as well as powers of the lognormal CDF. Their implementation is adapted from [`Mixture-biased-sampling.ipynb` in BlueSTARR-viz](https://github.com/Duke-IGVF/BlueSTARR-viz/blob/main/sim/Mixture-biased-sampling.ipynb), where the activation-dependent acceptance probabilities and resulting enrichments in positive activations are also visualized.

## License

BlueSTARR code is available under the MIT license. Pre-trained [BlueSTARR models and weights](https://huggingface.co/majoroslab/BlueSTARR) are also available under the MIT license.

## Citation and Acknowledgements

If you use this code, please cite the following paper:

> Venukuttan R, Doty R, Thomson A, Chen Y, Li B, Duan Y, Barrera A, Dura K, Ko K-Y, Lapp H, Reddy TE, Allen AS, Majoros WH (2026) Modeling gene regulatory perturbations via deep learning from high-throughput reporter assays. bioRxiv, :2026.03.27.714770. https://doi.org/10.64898/2026.03.27.714770

In BibTeX:

```bib
@article {Venukuttan2026.03,
    author = {Venukuttan, Revathy and Doty, Richard and Thomson, Alexander and Chen, Yutian and Li, Boyao and Duan, Yuncheng and Barrera, Alejandro and Dura, Katherine and Ko, Kuei-Yueh and Lapp, Hilmar and Reddy, Timothy E and Allen, Andrew S and Majoros, William H},
    title = {Modeling gene regulatory perturbations via deep learning from high-throughput reporter assays},
    elocation-id = {2026.03.27.714770},
    year = {2026},
    doi = {10.64898/2026.03.27.714770},
    publisher = {Cold Spring Harbor Laboratory},
    URL = {https://www.biorxiv.org/content/early/2026/03/31/2026.03.27.714770},
    eprint = {https://www.biorxiv.org/content/early/2026/03/31/2026.03.27.714770.full.pdf},
    journal = {bioRxiv}
}
```

BlueSTARR is inspired by and was originally derived from DeepSTARR. If you use BlueSTARR with a deep-learning network architecture substantially similar to one pioneered in DeepSTARR, please also cite DeepSTARR:

> Almeida BP de, Reiter F, Pagani M, Stark A (2022) DeepSTARR predicts enhancer activity from DNA sequence and enables the de novo design of synthetic enhancers. Nature Genetics, 54(5):613–624. https://doi.org/10.1038/s41588-022-01048-5

## Funding

This work was supported by the National Institute of General Medical Sciences (NIGMS) of the National Institutes of Health (NIH) under award number 1R35-GM150404 to W.H.M., and National Human Genome Research Institute (NHGRI) of NIH 5U01-HG011967, and NHGRI 5UM1-HG012053. Content is solely the responsibility of the authors.
