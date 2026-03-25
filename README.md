# BlueSTARR
BlueSTARR: predicting effects of regulatory variants

## Running BlueSTARR

Running the BlueSTARR code requires Python 3.10+ and the presence of a number of dependencies. These can be installed locally in the form of a conda environment, or alternatively use the Docker container automatically built and updated for the codebase.

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

### Processing STARRseq FASTQ files to BigWig format

To process FASTQ files into BigWig files, we use the [STARR-seq_pipeline](https://github.com/ReddyLab/cwl-pipelines/tree/main/v1.0/STARR-seq_pipeline) defined in [Common Workflow Language](https://www.commonwl.org) (CWL).

To execute CWL workflows, you will need a CWL engine, for example [`cwltool`](https://www.commonwl.org/user_guide/introduction/prerequisites.html#cwl-runner).

### Processing STARRseq BigWig files to count data and FASTA sequences

For generating the counts data file and FASTA sequences for training the model, the [WGSTARR_data_preprocessing notebook](WGSTARR_data_preprocessing.ipynb) was used. For each 300 bp training sequence, count files were generated from the per-replicate bigWigs produced in the previous step. These files contained signal values normalized by library size, for every replicate of both the input and output libraries.

### Downsampling

In its current implementation, the BlueSTARR training code loads the full dataset into memory prior to commencing the model training loop.  If this requires more memory than available by your compute resources, you can downsample the dataset.

We employ two downsampling strategies that differ in the acceptance probability for each record of counts (= each training sequence):

- **Unbiased downsampling:** each sequence is accepted with a fixed probability _N/M_, where _N_ is the desired sample size and _M_ is the total number of records being sampled. See the script [`downsample-nonuniform.py` in BlueSTARR_Evaluation_K562](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_K562/blob/main/leave-one-out/BlueSTARR/leave-one-out/downsampling/downsample-nonuniform.py).
- **Biased downsampling:** the acceptance probability is a function of the estimated frequency (or kernel density) distribution of the observed activation signal $\theta$ (RNA over DNA). The script [`downsample.py` in BlueSTARR_Evaluation_K562](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_K562/blob/main/leave-one-out/BlueSTARR/leave-one-out/downsampling/downsample.py) uses the empirical histogram-based PDF, where the acceptance probability for a record is $min(1, N/(M*B*p_i))$, where $p_i$ is the observed proportion of records in histogram bin _i_ into which the observed value of $\theta$ falls. The script [`downsample-biased.py` in BlueSTARR_Evaluation_A549](https://github.com/Duke-IGVF/BlueSTARR_Evaluation_A549/blob/main/full-set/BlueSTARR/downsample-biased.py) implements other functions, including PDFs and CDFs of lognormal distributions as well as powers of the lognormal CDF. Their implementation is adapted from [`Mixture-biased-sampling.ipynb` in BlueSTARR-viz](https://github.com/Duke-IGVF/BlueSTARR-viz/blob/main/sim/Mixture-biased-sampling.ipynb), where the activation-dependent acceptance probabilities and resulting enrichments in positive activations are also visualized.
