# this script has to be sourced, like so:
# . cudnn-liblic.sh

# Check if nvidia.cudnn module is present
if python3 -c "import nvidia.cudnn" &> /dev/null; then
    # Get the directory of the nvidia.cudnn module
    export CUDNN_PATH=$(python -c "import os; import nvidia.cudnn; print(os.path.dirname(nvidia.cudnn.__file__))")
    echo "Nvidia CUDNN found at $CUDNN_PATH"

    # Append or set $CUDNN_PATH/lib to LD_LIBRARY_PATH
    if [[ -z $LD_LIBRARY_PATH ]]; then
        export LD_LIBRARY_PATH=$CUDNN_PATH/lib
    else
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CUDNN_PATH/lib
    fi
else
    echo "Nvidia CUDNN python package not available, hence cannot point LD_LIBRARY_PATH to it"
fi
