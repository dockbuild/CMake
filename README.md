cmake for centos5 and manylinux1
================================

This **ONLY** purpose of this project is to distribute a binary package of
cmake working on centos 5 and manylinux1 [1].

### motivation

Distribution like Centos5 are useful to generate artefact expected to run on
a variety of Linux systems. It is for example useful in the context of project
like `dockcross <https://github.com/dockcross/dockcross>`_ and `dockbuild <https://github.com/dockbuild/dockbuild>`_.


### demonstration

The current binary distribution of CMake does NOT work on centos5.

First, download the binaries:


```console
CMAKE_ROOT=cmake-3.11.0-Linux-x86_64

curl -sLO https://cmake.org/files/v3.11/${CMAKE_ROOT}.tar.gz \
&& tar -xzf ${CMAKE_ROOT}.tar.gz
```


Then, executing on Centos 5 fails because of incompatible GLIBC.

```console
CENTOS_VERSION=5

docker run -ti -v $(pwd):/test centos:${CENTOS_VERSION} /test/${CMAKE_ROOT}/bin/cmake --version
/test/cmake-3.11.0-Linux-x86_64/bin/cmake: /lib64/libc.so.6: version `GLIBC_2.6' not found (required by /test/cmake-3.11.0-Linux-x86_64/bin/cmake)
```

Whereas it works well on Centos 6:

```console
CENTOS_VERSION=6

docker run -ti -v $(pwd):/test centos:${CENTOS_VERSION} /test/${CMAKE_ROOT}/bin/cmake --version
cmake version 3.11.0

CMake suite maintained and supported by Kitware (kitware.com/cmake).
```


Worth noting that `manylinux2010` (the successor of `manylinux1`) is based on Centos 6. See [2]


[1] https://www.python.org/dev/peps/pep-0513/

[2] https://www.python.org/dev/peps/pep-0571/


### generating the package

```console
mkdir /tmp/scratch && cd $_

# Download dockbuild image 
docker run --rm dockbuild/centos5-devtoolset2-gcc4 > ./dockbuild-centos5-devtoolset2-gcc4
chmod +x ./dockbuild-centos5-devtoolset2-gcc4

# Download OpenSSL
OPENSSL_ROOT=openssl-1.0.2o
OPENSSL_HASH=ec3f5c9714ba0fd45cb4e087301eb1336c317e0d20b575a125050470e8089e4d

curl -#LO https://www.openssl.org/source/${OPENSSL_ROOT}.tar.gz
echo "${OPENSSL_HASH}  ${OPENSSL_ROOT}.tar.gz" > ${OPENSSL_ROOT}.tar.gz.sha256
sha256sum -c ${OPENSSL_ROOT}.tar.gz.sha256

tar -xf ${OPENSSL_ROOT}.tar.gz

# Build OpenSSL
./dockbuild-centos5-devtoolset2-gcc4 bash -c "cd ${OPENSSL_ROOT}; ./config no-ssl2 no-shared -fPIC --prefix=/work/openssl-install"
./dockbuild-centos5-devtoolset2-gcc4 bash -c "cd ${OPENSSL_ROOT}; make"

# Download CMake
git clone git://github.com/kitware/cmake -b v3.11.0 --depth 1

# Configure CMake
./dockbuild-centos5-devtoolset2-gcc4 \
  cmake \
    -Bcmake-build -Hcmake \
    -GNinja \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_C_STANDARD:STRING=11 \
    -DCMAKE_CXX_STANDARD:STRING=14 \
    -DCMAKE_C_FLAGS:STRING="-D_POSIX_C_SOURCE=199506L -D_POSIX_SOURCE=1 -D_SVID_SOURCE=1 -D_BSD_SOURCE=1" \
    -DCMAKE_EXE_LINKER_FLAGS:STRING="-static-libstdc++ -static-libgcc" \
    -DCPACK_SYSTEM_NAME:STRING=Centos5-x86_64 \
    -DCMAKE_USE_OPENSSL:BOOL=ON \
    -DOPENSSL_CRYPTO_LIBRARY:STRING="/work/${OPENSSL_ROOT}/libcrypto.a;-pthread" \
    -DOPENSSL_INCLUDE_DIR:PATH=/work/${OPENSSL_ROOT}/include \
    -DOPENSSL_SSL_LIBRARY:FILEPATH=/work/${OPENSSL_ROOT}/libssl.a \
    -DBUILD_QtDialog:BOOL=FALSE \
    -DCMAKE_SKIP_BOOTSTRAP_TEST:STRING=TRUE

# Build and Package CMake
./dockbuild-centos5-devtoolset2-gcc4 bash -c "cd cmake-build; ninja package"
```

### certificates

If not explicitly specified using the ``TLS_CAINFO`` option associated with the CMake command ``FILE`` or
the CMake macro ``ExternalProject_Add``, CMake will look for certificates in the following locations:

```
/etc/pki/tls/certs/ca-bundle.crt
/etc/ssl/certs/ca-certificates.crt
/etc/ssl/certs
```

This means that the default certificate bundle associated older distribution need to be updated
using a recent one.

Updating the certificate on Centos5, could be following these steps:


First, download certifi package either on on a system with valid certificates or using an other mechanism to ensure
integrity of the downloaded package (e.g using checksum):

```
curl -LO https://files.pythonhosted.org/packages/15/d4/2f888fc463d516ff7bf2379a4e9a552fef7f22a94147655d9b1097108248/certifi-2018.1.18.tar.gz
tar -xf certifi-2018.1.18.tar.gz
SSL_CERT_FILE=./certifi-2018.1.18/certifi/cacert.pem
```

Second, copy ${SSL_CERT_FILE} to `/etc/pki/tls/certs/ca-bundle.crt`


