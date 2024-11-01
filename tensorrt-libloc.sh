# This script must be sourced in the same shell where you will run Python
# with Tensorflow so that the environment variables are set. Like this:
# $ source tensorrt-libloc.sh


# Check if the TensorRT libraries are present
if python3 -c "import tensorrt_libs" &> /dev/null; then
    tensorrt_lib=$(python -c "import os; import tensorrt_libs; print(os.path.dirname(tensorrt_libs.__file__))")
    echo "TensorRT library found at: $tensorrt_lib"
    echo "Adding TensorRT library path to LD_LIBRARY_PATH"
    if [[ -z $LD_LIBRARY_PATH ]] ; then
        export LD_LIBRARY_PATH=$tensorrt_lib
    else
        export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$tensorrt_lib
    fi
else
    echo "TensorRT library not found, skipping."
    exit 0
fi
