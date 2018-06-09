cmake for centos5 and manylinux1
================================

This **ONLY** purpose of this project is to distribute a binary package of
cmake working on centos 5 and manylinux1 [1].

See [demonstration](demonstration.md) to learn how compatibility of the current
cmake distribution with centos 5 was checked.

### motivation

Distribution like Centos5 are useful to generate artefact expected to run on
a variety of Linux systems. It is for example useful in the context of project
like `dockcross <https://github.com/dockcross/dockcross>`_ and `dockbuild <https://github.com/dockbuild/dockbuild>`_.

### generating the packages

```console
mkdir /tmp/scratch && cd $_

curl -LO -# https://raw.githubusercontent.com/dockbuild/CMake/welcome/generate_package.sh
chmod u+x ./generate_package.sh

CMAKE_VERSION=3.11.3

# Build x86 package
./generate_package.sh -cmake-version ${CMAKE_VERSION} -32

# Build x86_64 package
./generate_package.sh -cmake-version ${CMAKE_VERSION}
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


