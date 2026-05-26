#!/bin/bash
set -euo pipefail

expected="${1:?usage: test-openmp.sh intel-openmp|libgomp}"

found_expected=0

shopt -s nullglob
for lib in "${PREFIX}"/lib/python*/site-packages/bitsandbytes/libbitsandbytes_cpu*.so; do
    if [[ ! -f "${lib}" ]]; then
        continue
    fi

    if [[ "${expected}" == "intel-openmp" ]]; then
        if ldd "${lib}" | grep -Ei 'libgomp'; then
            echo "libgomp must not be linked when openmp_impl=intel-openmp: ${lib}"
            exit 1
        fi

        if ldd "${lib}" | grep -Ei 'libiomp5'; then
            found_expected=1
        fi
    elif [[ "${expected}" == "libgomp" ]]; then
        if ldd "${lib}" | grep -Ei 'libiomp5'; then
            echo "libiomp5 must not be linked when openmp_impl=libgomp: ${lib}"
            exit 1
        fi

        if ldd "${lib}" | grep -Ei 'libgomp'; then
            found_expected=1
        fi
    else
        echo "unsupported expected OpenMP runtime: ${expected}"
        exit 1
    fi
done

if [[ "${found_expected}" == "1" ]]; then
    exit 0
fi

echo "expected OpenMP runtime ${expected} was not found in libbitsandbytes_cpu dependencies."
exit 1
