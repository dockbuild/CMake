#!/bin/bash 

set -e
set -o pipefail

BUILD_SCRIPT="${BASH_SOURCE[0]}"
BUILD_SCRIPT_NAME=$(basename ${BUILD_SCRIPT})

BUILD=0
BUILD_IMAGE=dockbuild/centos5-devtoolset2-gcc4

BUILD_FLAG=
CPACK_PACKAGE_NAME_ARCH=x86_64
WRAPPER=""
OPENSSL_CONFIG_FLAG=""

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

# Cleanup
rm -rf ${OPENSSL_ROOT} openssl-install
rm -rf cmake cmake-build

# Download OpenSSL
OPENSSL_ROOT=openssl-1.0.2o
OPENSSL_HASH=ec3f5c9714ba0fd45cb4e087301eb1336c317e0d20b575a125050470e8089e4d

[ ! -f ${OPENSSL_ROOT}.tar.gz ] && curl -#LO https://www.openssl.org/source/${OPENSSL_ROOT}.tar.gz
echo "${OPENSSL_HASH}  ${OPENSSL_ROOT}.tar.gz" > ${OPENSSL_ROOT}.tar.gz.sha256
sha256sum -c ${OPENSSL_ROOT}.tar.gz.sha256

# Extract
tar -xf ${OPENSSL_ROOT}.tar.gz

# Configure and build OpenSSL
cd /work/${OPENSSL_ROOT}
${WRAPPER} ./config no-ssl2 no-shared -fPIC ${OPENSSL_CONFIG_FLAG} --prefix=/work/openssl-install
${WRAPPER} make
${WRAPPER} make install_sw

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
  -DCMAKE_EXE_LINKER_FLAGS:STRING="-static-libstdc++ -static-libgcc" \
  -DCPACK_SYSTEM_NAME:STRING=Centos5-${CPACK_PACKAGE_NAME_ARCH} \
  -DCMAKE_USE_OPENSSL:BOOL=ON \
  -DOPENSSL_CRYPTO_LIBRARY:STRING="/work/${OPENSSL_ROOT}/libcrypto.a;-pthread" \
  -DOPENSSL_INCLUDE_DIR:PATH=/work/${OPENSSL_ROOT}/include \
  -DOPENSSL_SSL_LIBRARY:FILEPATH=/work/${OPENSSL_ROOT}/libssl.a \
  -DBUILD_QtDialog:BOOL=FALSE \
  -DCMAKE_SKIP_BOOTSTRAP_TEST:STRING=TRUE

# Build and Package CMake
cd /work/cmake-build
${WRAPPER} ninja package
