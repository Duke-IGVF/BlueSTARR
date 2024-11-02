# BlueSTARR
BlueSTARR: predicting effects of regulatory variants

## Environment setup

### Creating a conda environment from scratch

1. Create a new conda environment with Python 3.10. (Later versions may work but have not been tested.)
   ```bash
   # you can also use -n YourEnvName instead of -p /path/to/env
   conda create -p /path/to/new/conda/env -c conda-forge python=3.10
   ```
2. Install the python dependencies using `pip`:
   ```bash
   pip install -r requirements.txt
   ```

### Cloning a previously exported conda environment

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
