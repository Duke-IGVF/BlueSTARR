#!/bin/bash

# Fix for TensorRT libraries not being found, resulting in 
# Tensorflow not being able to load the TensorRT plugin.
#
# This script will create a symbolic link to the TensorRT libraries
# with the correct version number in the name.

# Check if the TensorRT libraries are present
if python3 -c "import tensorrt_libs" &> /dev/null; then
    tensorrt_lib=$(python -c "import os; import tensorrt_libs; print(os.path.dirname(tensorrt_libs.__file__))")
    echo "TensorRT library found at: $tensorrt_lib"

    # Check if the full version library is present
    libnvinfer=$(ls ${tensorrt_lib}/libnvinfer.so.* 2> /dev/null)
    libbuilder=$(ls ${tensorrt_lib}/libnvinfer_builder_resource.so.* 2> /dev/null)
    if [[ -z "$libbuilder" || -z "$libnvinfer" ]]; then
        echo "Expected library or libraries not found, skipping fix."
        exit 1
    fi
    vinfer=${libnvinfer##*.so.}
    vbuilderdiff=${libbuilder##*.so.${vinfer}}
    if [[ -z $vbuilderdiff ]]; then
        echo "Builder library version is the same as the main library, skipping fix."
    else
        for lib in $tensorrt_lib/lib*.so.${vinfer} ; do
            # test whether target already exists
            if [ -e $lib${vbuilderdiff} ]; then
                echo "${vinfer}${vbuilderdiff} for "$(basename $lib)" exists, skipping."
            else
                echo "Creating symbolic link with version ${vinfer}${vbuilderdiff} for "$(basename $lib)
                ln -s $lib $lib${vbuilderdiff}
            fi
        done
    fi
else
    echo "TensorRT library not found, skipping fix."
    exit 0
fi
