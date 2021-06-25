#!/bin/bash 

set -e
set -o pipefail

BUILD_SCRIPT="${BASH_SOURCE[0]}"
BUILD_SCRIPT_NAME=$(basename ${BUILD_SCRIPT})

BUILD=0
BUILD_IMAGE=dockbuild/centos7-devtoolset7-gcc7

BUILD_FLAG=
CPACK_PACKAGE_NAME_ARCH=x86_64
WRAPPER=""
OPENSSL_CONFIG_FLAG=""
LIBUV_LIB_DIR=lib64

#-----------------------------------------------------------------------------
while [ $# -gt 0 ]; do
  case "$1" in
    -cmake-version)
      CMAKE_VERSION=$2
      shift
      ;;
    -32)
      BUILD_FLAG="-32"
      WRAPPER="linux32"
      OPENSSL_CONFIG_FLAG="-m32"
      BUILD_IMAGE=dockcross/manylinux-x86
      CPACK_PACKAGE_NAME_ARCH=x86
      LIBUV_LIB_DIR=lib
      ;;
    -build)
      BUILD=1
      ;;
    *)
      echo "Usage: Usage: ${0##*/} X.Y.Z [-32]"
      exit 1
      ;;
  esac
  shift
done

if [ "${CMAKE_VERSION}" == "" ]; then
  echo >&2 'error: argument "-cmake-version X.Y.Z" is missing'
  exit 1
fi

#-----------------------------------------------------------------------------
if [ $BUILD == 0 ]; then

  if ! command -v docker &> /dev/null; then
	  echo >&2 'error: "docker" not found!'
	  exit 1
  fi

  # Copy script in current directory to ensure it is available in the docker context
  if [ $(readlink -e $(dirname ${BUILD_SCRIPT})) != $(pwd) ]; then
    cp ${BUILD_SCRIPT} ${BUILD_SCRIPT_NAME}
  fi

  # Download dockbuild image
  BUILD_IMAGE_SCRIPT=${BUILD_IMAGE/\//-}
  docker run --rm ${BUILD_IMAGE} > ./${BUILD_IMAGE_SCRIPT}
  chmod +x ./${BUILD_IMAGE_SCRIPT}

  # Execute package build script
  ./${BUILD_IMAGE_SCRIPT} bash -c "./${BUILD_SCRIPT_NAME} -cmake-version ${CMAKE_VERSION} -build ${BUILD_FLAG}"
  exit $?
fi

set -x

#-----------------------------------------------------------------------------
OPENSSL_VERSION_L="j"
OPENSSL_VERSION="1.1.1"
OPENSSL_VERSION_FULL=${OPENSSL_VERSION}${OPENSSL_VERSION_L}
OPENSSL_ROOT=openssl-${OPENSSL_VERSION_FULL}

LIBUV_VERSION="v1.41.0"
LIBUV_ROOT=libuv-${LIBUV_VERSION}

#-----------------------------------------------------------------------------
# Cleanup
rm -rf ${OPENSSL_ROOT} openssl-install
rm -rf ${LIBUV_ROOT} libuv-build libuv-install
rm -rf cmake cmake-build

# Download OpenSSL
OPENSSL_URL="https://www.openssl.org/source/old/${OPENSSL_VERSION}/${OPENSSL_ROOT}.tar.gz"
OPENSSL_HASH=aaf2fcb575cdf6491b98ab4829abf78a3dec8402b8b81efc8f23c00d443981bf

[ ! -f ${OPENSSL_ROOT}.tar.gz ] && curl -#LO ${OPENSSL_URL}
echo "${OPENSSL_HASH}  ${OPENSSL_ROOT}.tar.gz" > ${OPENSSL_ROOT}.tar.gz.sha256
sha256sum -c ${OPENSSL_ROOT}.tar.gz.sha256

# Extract
tar -xf ${OPENSSL_ROOT}.tar.gz

# Configure and build OpenSSL
cd /work/${OPENSSL_ROOT}
${WRAPPER} ./config no-ssl2 no-shared -fPIC ${OPENSSL_CONFIG_FLAG} --prefix=/work/openssl-install
${WRAPPER} make
${WRAPPER} make install_sw

#-----------------------------------------------------------------------------
# Download libuv
LIBUV_URL=https://dist.libuv.org/dist/${LIBUV_VERSION}/${LIBUV_ROOT}.tar.gz
LIBUV_HASH=1184533907e1ddad9c0dcd30a5abb0fe25288c287ff7fee303fff7b9b2d6eb6e

[ ! -f ${LIBUV_ROOT}.tar.gz ] && curl -#LO ${LIBUV_URL}
echo "${LIBUV_HASH}  ${LIBUV_ROOT}.tar.gz" > ${LIBUV_ROOT}.tar.gz.sha256
sha256sum -c ${LIBUV_ROOT}.tar.gz.sha256

# Extract
tar -xf ${LIBUV_ROOT}.tar.gz

# Configure and build libuv
cmake \
  -Blibuv-build -H${LIBUV_ROOT} \
  -GNinja \
  -DCMAKE_INSTALL_PREFIX:PATH=/work/libuv-install
cmake --build libuv-build --target install

#-----------------------------------------------------------------------------
# Download CMake
cd /work/
git clone git://github.com/kitware/cmake -b v${CMAKE_VERSION} --depth 1

# Configure CMake
${WRAPPER} cmake \
  -Bcmake-build -Hcmake \
  -GNinja \
  -DCMAKE_BUILD_TYPE:STRING=Release \
  -DCMAKE_C_STANDARD:STRING=11 \
  -DCMAKE_CXX_STANDARD:STRING=14 \
  -DCMAKE_C_FLAGS:STRING="-D_POSIX_C_SOURCE=199506L -D_POSIX_SOURCE=1 -D_SVID_SOURCE=1 -D_BSD_SOURCE=1" \
  -DCMAKE_EXE_LINKER_FLAGS:STRING="-static-libstdc++ -static-libgcc -lrt" \
  -DCPACK_SYSTEM_NAME:STRING=Centos5-${CPACK_PACKAGE_NAME_ARCH} \
  -DCMAKE_USE_OPENSSL:BOOL=ON \
  -DOPENSSL_CRYPTO_LIBRARY:STRING="/work/${OPENSSL_ROOT}/libcrypto.a;-pthread" \
  -DOPENSSL_INCLUDE_DIR:PATH=/work/${OPENSSL_ROOT}/include \
  -DOPENSSL_SSL_LIBRARY:FILEPATH=/work/${OPENSSL_ROOT}/libssl.a \
  -DCMAKE_USE_SYSTEM_LIBRARY_LIBUV:BOOL=ON \
  -DLibUV_LIBRARY:FILEPATH=/work/libuv-install/${LIBUV_LIB_DIR}/libuv_a.a \
  -DLibUV_INCLUDE_DIR:PATH=/work/libuv-install/include \
  -DBUILD_QtDialog:BOOL=FALSE \
  -DCMAKE_SKIP_BOOTSTRAP_TEST:STRING=TRUE

# Build and Package CMake
cd /work/cmake-build
${WRAPPER} ninja package
