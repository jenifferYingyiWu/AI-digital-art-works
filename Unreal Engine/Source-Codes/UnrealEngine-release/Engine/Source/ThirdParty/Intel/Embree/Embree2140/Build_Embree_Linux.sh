#!/bin/bash

# Build instructions:
#
# 1. Run this script
#   ./Build_Embree_Linux.sh
#
# 2. Binaries should be in Build-RelWithDebInfo.x86_64-unknown-linux-gnu directory
#

set -eu

export UE_SDKS_ROOT="${UE_SDKS_ROOT:-/epic}"
export LINUX_MULTIARCH_ROOT="${LINUX_MULTIARCH_ROOT:-${UE_SDKS_ROOT}/HostLinux/Linux_x64/v17_clang-10.0.1-centos7}"

if [[ ! -d "${LINUX_MULTIARCH_ROOT}" ]]; then
    echo ERROR: LINUX_MULTIARCH_ROOT envvar not set
    exit 1
fi

echo "Using compiler at: ${LINUX_MULTIARCH_ROOT}"

SCRIPT_DIR=$(cd "$(dirname "$BASH_SOURCE")" ; pwd)
THIRD_PARTY=$(cd "${SCRIPT_DIR}/../../.." ; pwd)

BuildEmbree()
{
    export ARCH=$1
    export FLAVOR=$2
    local BUILD_DIR=${SCRIPT_DIR}/Build-${FLAVOR}.${ARCH}

    echo "Building ${ARCH}"
    rm -rf ${BUILD_DIR}
    mkdir -p ${BUILD_DIR}

    pushd ${BUILD_DIR}

    set -x
    cmake -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE="/tmp/__cmake_toolchain.cmake" \
      -DCMAKE_MAKE_PROGRAM=$(which ninja) \
      -DCMAKE_BUILD_TYPE=${FLAVOR} \
      -DEMBREE_TBB_ROOT=${THIRD_PARTY}/Intel/TBB/IntelTBB-2019u8 \
      -DTBB_INCLUDE_DIR=${THIRD_PARTY}/Intel/TBB/IntelTBB-2019u8/include \
      -DTBB_LIBRARY=${THIRD_PARTY}/Intel/TBB/IntelTBB-2019u8/lib/Linux/libtbb.a \
      -DTBB_LIBRARY_MALLOC=${THIRD_PARTY}/Intel/TBB/IntelTBB-2019u8/lib/Linux/libtbbmalloc.a \
      -DEMBREE_ISPC_EXECUTABLE=${THIRD_PARTY}/Intel/ISPC/bin/Linux/ispc \
      -DEMBREE_TUTORIALS=OFF \
      -DEMBREE_MAX_ISA=AVX2 \
      -DEMBREE_ISA_SSE2=ON \
      -DEMBREE_ISA_SSE42=ON \
      -DEMBREE_ISA_AVX=ON \
      -DEMBREE_ISA_AVX2=ON \
      -DEMBREE_ISA_AVX512KNL=OFF \
      -DEMBREE_ISA_AVX512SKX=OFF \
      -DEMBREE_ISPC_SUPPORT=ON \
      -DEMBREE_STATIC_LIB=OFF \
      -DEMBREE_TUTORIALS=OFF \
      -DEMBREE_RAY_MASK=OFF \
      -DEMBREE_STAT_COUNTERS=OFF \
      -DEMBREE_BACKFACE_CULLING=OFF \
      -DEMBREE_INTERSECTION_FILTER=ON \
      -DEMBREE_INTERSECTION_FILTER_RESTORE=ON \
      -DEMBREE_IGNORE_INVALID_RAYS=OFF \
      -DEMBREE_TASKING_SYSTEM=TBB \
      -DEMBREE_GEOMETRY_TRIANGLES=ON \
      -DEMBREE_GEOMETRY_QUADS=ON \
      -DEMBREE_GEOMETRY_LINES=ON \
      -DEMBREE_GEOMETRY_HAIR=ON \
      -DEMBREE_GEOMETRY_SUBDIV=ON \
      -DEMBREE_GEOMETRY_USER=ON \
      -DEMBREE_RAY_PACKETS=ON \
      ${SCRIPT_DIR}/src
    set +x

    echo
    ninja
    echo

    popd
}

( cat <<_EOF_
  ## autogenerated by ${BASH_SOURCE} script
  SET(LINUX_MULTIARCH_ROOT \$ENV{LINUX_MULTIARCH_ROOT})
  SET(ARCHITECTURE_TRIPLE \$ENV{ARCH})

  message (STATUS "LINUX_MULTIARCH_ROOT is '\${LINUX_MULTIARCH_ROOT}'")
  message (STATUS "ARCHITECTURE_TRIPLE is '\${ARCHITECTURE_TRIPLE}'")

  SET(CMAKE_CROSSCOMPILING TRUE)
  SET(CMAKE_SYSTEM_NAME Linux)
  SET(CMAKE_SYSTEM_VERSION 1)

  # sysroot
  SET(CMAKE_SYSROOT \${LINUX_MULTIARCH_ROOT}/\${ARCHITECTURE_TRIPLE})

  SET(CMAKE_LIBRARY_ARCHITECTURE \${ARCHITECTURE_TRIPLE})

  # specify the cross compiler
  SET(CMAKE_C_COMPILER            \${CMAKE_SYSROOT}/bin/clang)
  SET(CMAKE_C_COMPILER_TARGET     \${ARCHITECTURE_TRIPLE})
  SET(CMAKE_C_FLAGS "-fms-extensions -target      \${ARCHITECTURE_TRIPLE}")

  include_directories("${THIRD_PARTY}/Linux/LibCxx/include")
  include_directories("${THIRD_PARTY}/Linux/LibCxx/include/c++/v1")

  set(CMAKE_LINKER_FLAGS "-stdlib=libc++ -L${THIRD_PARTY}/Linux/LibCxx/lib/Linux/\${ARCHITECTURE_TRIPLE}/ ${THIRD_PARTY}/Linux/LibCxx/lib/Linux/\${ARCHITECTURE_TRIPLE}/libc++.a ${THIRD_PARTY}/Linux/LibCxx/lib/Linux/\${ARCHITECTURE_TRIPLE}/libc++abi.a -lpthread")
  set(CMAKE_EXE_LINKER_FLAGS      "\${CMAKE_LINKER_FLAGS}")
  set(CMAKE_MODULE_LINKER_FLAGS   "\${CMAKE_LINKER_FLAGS}")
  set(CMAKE_SHARED_LINKER_FLAGS   "\${CMAKE_LINKER_FLAGS}")
  #set(CMAKE_STATIC_LINKER_FLAGS   "\${CMAKE_LINKER_FLAGS}")

  SET(CMAKE_CXX_COMPILER          \${CMAKE_SYSROOT}/bin/clang++)
  SET(CMAKE_CXX_COMPILER_TARGET   \${ARCHITECTURE_TRIPLE})
  SET(CMAKE_CXX_FLAGS             "-std=c++1z -fms-extensions")
  # https://stackoverflow.com/questions/25525047/cmake-generator-expression-differentiate-c-c-code
  add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-nostdinc++>)

  SET(CMAKE_ASM_COMPILER          \${CMAKE_SYSROOT}/bin/clang)

  SET(CMAKE_FIND_ROOT_PATH        \${LINUX_MULTIARCH_ROOT})

  # hoping to force it to use ar
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

_EOF_
) > /tmp/__cmake_toolchain.cmake

if [ "$#" -eq 1 ] && [ "$1" == "-debug" ]; then
	BuildEmbree x86_64-unknown-linux-gnu Debug
else
	BuildEmbree x86_64-unknown-linux-gnu RelWithDebInfo
fi