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
