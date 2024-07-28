#!/bin/bash

set -e

LIBRARY_NAME="OpenVDB"
REPOSITORY_NAME="openvdb"

BUILD_SCRIPT_NAME="$(basename $BASH_SOURCE)"
BUILD_SCRIPT_DIR=`cd $(dirname "$BASH_SOURCE"); pwd`

UsageAndExit()
{
    echo "Build $LIBRARY_NAME for use with Unreal Engine on Linux"
    echo
    echo "Usage:"
    echo
    echo "    $BUILD_SCRIPT_NAME <$LIBRARY_NAME Version> <Architecture Name>"
    echo
    echo "Usage examples:"
    echo
    echo "    $BUILD_SCRIPT_NAME 8.1.0 x86_64-unknown-linux-gnu"
    echo "      -- Installs $LIBRARY_NAME version 8.1.0 for x86_64 architecture."
    echo
    echo "    $BUILD_SCRIPT_NAME 8.1.0 aarch64-unknown-linux-gnueabi"
    echo "      -- Installs $LIBRARY_NAME version 8.1.0 for arm64 architecture."
    echo
    exit 1
}

# Get version and architecture from arguments.
LIBRARY_VERSION=$1
if [ -z "$LIBRARY_VERSION" ]
then
    UsageAndExit
fi

ARCH_NAME=$2
if [ -z "$ARCH_NAME" ]
then
    UsageAndExit
fi

UE_MODULE_LOCATION=`cd $BUILD_SCRIPT_DIR/../..; pwd`
UE_THIRD_PARTY_LOCATION=`cd $UE_MODULE_LOCATION/..; pwd`
UE_ENGINE_LOCATION=`cd $UE_THIRD_PARTY_LOCATION/../..; pwd`

ZLIB_LOCATION="$UE_THIRD_PARTY_LOCATION/zlib/v1.2.8"
ZLIB_INCLUDE_LOCATION="$ZLIB_LOCATION/include/Unix/$ARCH_NAME"
ZLIB_LIB_LOCATION="$ZLIB_LOCATION/lib/Unix/$ARCH_NAME/libz.a"

TBB_LOCATION="$UE_THIRD_PARTY_LOCATION/Intel/TBB/IntelTBB-2019u8"
TBB_INCLUDE_LOCATION="$TBB_LOCATION/include"
TBB_LIB_LOCATION="$TBB_LOCATION/lib/Linux"

# The version of TBB on Linux for x86_64 is in the root of the library
# directory while arm64 is in a subdirectory that matches the architecture
# name.
if [[ $ARCH_NAME != x86_64* ]]
then
    TBB_LIB_LOCATION="$TBB_LIB_LOCATION/$ARCH_NAME"
fi

BLOSC_LOCATION="$UE_THIRD_PARTY_LOCATION/Blosc/Deploy/c-blosc-1.21.0"
BLOSC_INCLUDE_LOCATION="$BLOSC_LOCATION/include"
BLOSC_LIB_LOCATION="$BLOSC_LOCATION/Unix/$ARCH_NAME"
BLOSC_LIBRARY_LOCATION_RELEASE="$BLOSC_LIB_LOCATION/libblosc.a"
BLOSC_LIBRARY_LOCATION_DEBUG="$BLOSC_LIB_LOCATION/libblosc_d.a"

BOOST_LOCATION="$UE_THIRD_PARTY_LOCATION/Boost/boost-1_80_0"
BOOST_INCLUDE_LOCATION="$BOOST_LOCATION/include"
BOOST_LIB_LOCATION="$BOOST_LOCATION/lib/Unix/$ARCH_NAME"

SOURCE_LOCATION="$UE_MODULE_LOCATION/$REPOSITORY_NAME-$LIBRARY_VERSION"

BUILD_LOCATION="$UE_MODULE_LOCATION/Intermediate"

# Specify all of the include/bin/lib directory variables so that CMake can
# compute relative paths correctly for the imported targets.
INSTALL_INCLUDEDIR=include
INSTALL_BIN_DIR="Unix/$ARCH_NAME/bin"
INSTALL_LIB_DIR="Unix/$ARCH_NAME/lib"

INSTALL_LOCATION="$UE_MODULE_LOCATION/Deploy/$REPOSITORY_NAME-$LIBRARY_VERSION"
INSTALL_INCLUDE_LOCATION="$INSTALL_LOCATION/$INSTALL_INCLUDEDIR"
INSTALL_UNIX_ARCH_LOCATION="$INSTALL_LOCATION/Unix/$ARCH_NAME"

rm -rf $BUILD_LOCATION
rm -rf $INSTALL_INCLUDE_LOCATION
rm -rf $INSTALL_UNIX_ARCH_LOCATION

mkdir $BUILD_LOCATION
pushd $BUILD_LOCATION > /dev/null

# Run Engine/Build/BatchFiles/Linux/SetupToolchain.sh first to ensure
# that the toolchain is setup and verify that this name matches.
TOOLCHAIN_NAME=v20_clang-13.0.1-centos7

UE_TOOLCHAIN_LOCATION="$UE_ENGINE_LOCATION/Extras/ThirdPartyNotUE/SDKs/HostLinux/Linux_x64/$TOOLCHAIN_NAME"

C_FLAGS=""
CXX_FLAGS="-fvisibility=hidden -I$UE_THIRD_PARTY_LOCATION/Unix/LibCxx/include/c++/v1"
LINKER_FLAGS="-nodefaultlibs -L$UE_THIRD_PARTY_LOCATION/Unix/LibCxx/lib/Unix/$ARCH_NAME/ -lc++ -lc++abi -lm -lc -lgcc_s -lgcc"

# Determine whether we're cross compiling for an architecture that doesn't
# match the host. This is the way that CMake determines the value for the
# CMAKE_HOST_SYSTEM_PROCESSOR variable.
HOST_SYSTEM_PROCESSOR=`uname -m`
TARGET_SYSTEM_PROCESSOR=$HOST_SYSTEM_PROCESSOR

if [[ $ARCH_NAME != $HOST_SYSTEM_PROCESSOR* ]]
then
    ARCH_NAME_PARTS=(${ARCH_NAME//-/ })
    TARGET_SYSTEM_PROCESSOR=${ARCH_NAME_PARTS[0]}
fi

( cat <<_EOF_
    # Auto-generated by script: $BUILD_SCRIPT_DIR/$BUILD_SCRIPT_NAME

    message (STATUS "UE_TOOLCHAIN_LOCATION is '${UE_TOOLCHAIN_LOCATION}'")
    message (STATUS "ARCH_NAME is '${ARCH_NAME}'")
    message (STATUS "TARGET_SYSTEM_PROCESSOR is '${TARGET_SYSTEM_PROCESSOR}'")

    set(CMAKE_SYSTEM_NAME Linux)
    set(CMAKE_SYSTEM_PROCESSOR ${TARGET_SYSTEM_PROCESSOR})

    set(CMAKE_SYSROOT ${UE_TOOLCHAIN_LOCATION}/${ARCH_NAME})
    set(CMAKE_LIBRARY_ARCHITECTURE ${ARCH_NAME})

    set(CMAKE_C_COMPILER \${CMAKE_SYSROOT}/bin/clang)
    set(CMAKE_C_COMPILER_TARGET ${ARCH_NAME})
    set(CMAKE_C_FLAGS "-target ${ARCH_NAME} ${C_FLAGS}")

    set(CMAKE_CXX_COMPILER \${CMAKE_SYSROOT}/bin/clang++)
    set(CMAKE_CXX_COMPILER_TARGET ${ARCH_NAME})
    set(CMAKE_CXX_FLAGS "-target ${ARCH_NAME} ${CXX_FLAGS}")

    set(CMAKE_EXE_LINKER_FLAGS "${LINKER_FLAGS}")
    set(CMAKE_MODULE_LINKER_FLAGS "${LINKER_FLAGS}")
    set(CMAKE_SHARED_LINKER_FLAGS "${LINKER_FLAGS}")

    set(CMAKE_FIND_ROOT_PATH "${UE_TOOLCHAIN_LOCATION};${UE_THIRD_PARTY_LOCATION}")
    set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
    set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
    set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
_EOF_
) > /tmp/__cmake_toolchain.cmake

CMAKE_ARGS=(
    -DCMAKE_TOOLCHAIN_FILE="/tmp/__cmake_toolchain.cmake"
    -DCMAKE_INSTALL_PREFIX="$INSTALL_LOCATION"
    -DCMAKE_INSTALL_INCLUDEDIR="$INSTALL_INCLUDEDIR"
    -DCMAKE_INSTALL_BINDIR="$INSTALL_BIN_DIR"
    -DCMAKE_INSTALL_LIBDIR="$INSTALL_LIB_DIR"
    -DZLIB_INCLUDE_DIR="$ZLIB_INCLUDE_LOCATION"
    -DZLIB_LIBRARY="$ZLIB_LIB_LOCATION"
    -DTBB_INCLUDEDIR="$TBB_INCLUDE_LOCATION"
    -DTBB_LIBRARYDIR="$TBB_LIB_LOCATION"
    -DBLOSC_INCLUDEDIR="$BLOSC_INCLUDE_LOCATION"
    -DBLOSC_LIBRARYDIR="$BLOSC_LIB_LOCATION"
    -DBLOSC_USE_STATIC_LIBS=ON
    -DBlosc_LIBRARY_RELEASE="$BLOSC_LIBRARY_LOCATION_RELEASE"
    -DBlosc_LIBRARY_DEBUG="$BLOSC_LIBRARY_LOCATION_DEBUG"
    -DBoost_NO_BOOST_CMAKE=ON
    -DBoost_NO_SYSTEM_PATHS=ON
    -DBOOST_INCLUDEDIR="$BOOST_INCLUDE_LOCATION"
    -DBOOST_LIBRARYDIR="$BOOST_LIB_LOCATION"
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DUSE_PKGCONFIG=OFF
    -DOPENVDB_BUILD_BINARIES=OFF
    -DOPENVDB_INSTALL_CMAKE_MODULES=OFF
    -DOPENVDB_CORE_SHARED=OFF
    -DOPENVDB_CORE_STATIC=ON
    -DCMAKE_DEBUG_POSTFIX=_d
)

# Finding Boost requires specifying the architecture suffix.
if [[ $ARCH_NAME == x86_64* ]]
then
    CMAKE_ARGS+=(-DBoost_ARCHITECTURE="-x64")
else
    CMAKE_ARGS+=(-DBoost_ARCHITECTURE="-a64")
fi

NUM_CPU=`grep -c ^processor /proc/cpuinfo`

echo Configuring Debug build for $LIBRARY_NAME version $LIBRARY_VERSION...
cmake -G "Unix Makefiles" $SOURCE_LOCATION -DCMAKE_BUILD_TYPE=Debug "${CMAKE_ARGS[@]}"

echo Building $LIBRARY_NAME for Debug...
cmake --build . -j$NUM_CPU

echo Installing $LIBRARY_NAME for Debug...
cmake --install .

# The Unix Makefiles generator does not support multiple configurations, so we
# need to re-configure for Release.
echo Configuring Release build for $LIBRARY_NAME version $LIBRARY_VERSION...
cmake -G "Unix Makefiles" $SOURCE_LOCATION -DCMAKE_BUILD_TYPE=Release "${CMAKE_ARGS[@]}"

echo Building $LIBRARY_NAME for Release...
cmake --build . -j$NUM_CPU

echo Installing $LIBRARY_NAME for Release...
cmake --install .

popd > /dev/null

echo Done.