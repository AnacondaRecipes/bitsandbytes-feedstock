#!/bin/bash

set -exuo pipefail

if [[ "$OSTYPE" == "darwin"* ]]; then
    # skbuild considers that only the major version is important for the deployment target
    # https://github.com/scikit-build/scikit-build/blob/main/skbuild%2Fconstants.py#L92-L94
    export CMAKE_ARGS="${CMAKE_ARGS} -DCMAKE_OSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET%.*}.0"
fi

# bitsandbytes' cmake config will produce only one .so per backend build
# but we always need the generic "cpu" backend even for CUDA-enabled builds or import will fail
# if in an environment with CUDA but without a GPU

# Build the generic "cpu" backend
# this will create libbitsandbytes_cpu.so in the the bitsandbytes folder
mkdir -p build/cpu
pushd build/cpu
cmake ${CMAKE_ARGS} -DCOMPUTE_BACKEND=cpu -GNinja ../..
ninja
popd

# CUDA enabled build. This will create libbitsandbytes_cuda.so
# Even in a CUDA build we will still bundle the _cpu.so as a fallback if no GPUs are available
if [[ "${cuda_compiler_version:-None}" != "None" ]]; then
  mkdir -p build/cuda
  pushd build/cuda
  cmake ${CMAKE_ARGS} -DCOMPUTE_BACKEND=cuda -DCOMPUTE_CAPABILITY="50;60;70;75;80;86;90;100;120" -GNinja ../..
  ninja
  popd
fi

# MPS/Metal build requires Xcode (not just Command Line Tools) for the Metal compiler
if [[ "${gpu_variant:-None}" == "metal" ]]; then
  # Use -S and -B to avoid relative path issues with Metal compiler
  cmake ${CMAKE_ARGS} -DCOMPUTE_BACKEND=mps -GNinja -S . -B build/mps
  cmake --build build/mps
fi

# This will automatically pull in all .so files we've built
# on a CPU only build this will only be one .so, on CUDA both the CPU and CUDA variants
# Skip CMake during pip install since we already built the binaries above
export BNB_SKIP_CMAKE=1
pip install --no-deps --no-build-isolation -vvv .
