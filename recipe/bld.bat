@echo off
setlocal enabledelayedexpansion

:: bitsandbytes' cmake config will produce only one .dll per backend build
:: but we always need the generic "cpu" backend even for CUDA-enabled builds or import will fail
:: if in an environment with CUDA but without a GPU

:: Build the generic "cpu" backend
:: this will create libbitsandbytes_cpu.dll in the bitsandbytes folder
mkdir build\cpu
pushd build\cpu
cmake %CMAKE_ARGS% -DCOMPUTE_BACKEND=cpu -GNinja ..\..
if errorlevel 1 exit 1
ninja
if errorlevel 1 exit 1
popd

:: CUDA enabled build. This will create libbitsandbytes_cuda.dll
:: Even in a CUDA build we will still bundle the _cpu.dll as a fallback if no GPUs are available
if not "%cuda_compiler_version%"=="None" (
    mkdir build\cuda
    pushd build\cuda
    cmake %CMAKE_ARGS% -DCOMPUTE_BACKEND=cuda -DCOMPUTE_CAPABILITY="50;60;70;75;80;86;90;100;120" -GNinja ..\..
    if errorlevel 1 exit 1
    ninja
    if errorlevel 1 exit 1
    popd
)

:: This will automatically pull in all .dll files we've built
:: on a CPU only build this will only be one .dll, on CUDA both the CPU and CUDA variants
:: Skip CMake during pip install since we already built the binaries above
set BNB_SKIP_CMAKE=1
pip install --no-deps --no-build-isolation -vvv .
if errorlevel 1 exit 1
