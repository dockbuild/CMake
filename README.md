cmake for centos5 and manylinux1
================================

This **ONLY** purpose of this project is to distribute a binary package of
cmake working on centos 5 and manylinux1 [1].

See [demonstration](demonstration.md) to learn how compatibility of the current
cmake distribution with centos 5 was checked.

## motivation

Distribution like Centos5 are useful to generate artefact expected to run on
a variety of Linux systems. It is for example useful in the context of project
like `dockcross <https://github.com/dockcross/dockcross>`_ and `dockbuild <https://github.com/dockbuild/dockbuild>`_.

## maintainers: making a CMake Centos5 release

### generating the packages

```console
mkdir -p /tmp/scratch && cd $_

curl -LO -# https://raw.githubusercontent.com/dockbuild/CMake/welcome/generate_package.sh && \
chmod u+x ./generate_package.sh

CMAKE_VERSION=3.12.1

# Build x86 package
./generate_package.sh -cmake-version ${CMAKE_VERSION} -32 && \
mv cmake-build/*.tar.gz .

# Build x86_64 package
./generate_package.sh -cmake-version ${CMAKE_VERSION} && \
mv cmake-build/*.tar.gz .
```

### uploading the packages

```console
mkdir -p /tmp/scratch && cd $_

git clone git@github.com:kitware/cmake --branch v${CMAKE_VERSION} cmake-release && \
cd cmake-release && \
git remote add dockbuild git@github.com:dockbuild/cmake && \
git push dockbuild v${CMAKE_VERSION}:v${CMAKE_VERSION} && \
cd ..

mkvirtualenv dockbuild-cmake && \
pip install githubrelease

export GITHUB_TOKEN=xxxxx

githubrelease release dockbuild/cmake create v${CMAKE_VERSION} --name "v${CMAKE_VERSION} for Centos5" --publish cmake-${CMAKE_VERSION}-Centos5-*.tar.gz

deactivate && \
rmvirtualenv dockbuild-cmake
```

## misceanelous

### updating SSL certificates on Centos5

If not explicitly specified using the ``TLS_CAINFO`` option associated with the CMake command ``FILE`` or
the CMake macro ``ExternalProject_Add``, CMake will look for certificates in the following locations:

```
/etc/pki/tls/certs/ca-bundle.crt
/etc/ssl/certs/ca-certificates.crt
/etc/ssl/certs
```

This means that the default certificate bundle associated with older linux distribution need to be updated
using a recent one.

Updating the certificate on Centos5, could be done following these steps:


First, download certifi package either on on a system with valid certificates or using an other mechanism to ensure
integrity of the downloaded package (e.g using checksum):

```
curl -LO https://files.pythonhosted.org/packages/15/d4/2f888fc463d516ff7bf2379a4e9a552fef7f22a94147655d9b1097108248/certifi-2018.1.18.tar.gz
tar -xf certifi-2018.1.18.tar.gz
SSL_CERT_FILE=./certifi-2018.1.18/certifi/cacert.pem
```

Second, copy `${SSL_CERT_FILE}` to `/etc/pki/tls/certs/ca-bundle.crt`


