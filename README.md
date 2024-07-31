# BlueSTARR
BlueSTARR: predicting effects of regulatory variants

## Dependencies

The Python dependencies are in `requirements.txt`. You can install them like so (if not in the root directory of the code, give the full path for `requirements.txt`):
```sh
pip install -r requirements.txt`
```

This assumes that you have write-permission to the package installation directory of the Python interpreter you're using. This can be accomplished in different ways (e.g., using `--user` or prefixing the command with `sudo`), but the most recommended way is by first creating a conda environment and then activating it:
```sh
conda create -n BlueSTARR python=3.11
conda activate BlueSTARR
```

If you are on a machine with GPU and supported by Tensorflow, you may need to run the following before running the `BlueSTARR-multitask.py` command for Tensorflow to succeed in using your GPU:
```sh
source cudnn-libloc.sh
```
