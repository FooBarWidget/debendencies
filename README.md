# Debian package shared library dependencies inferer

Debendable scans executables and shared libraries for their shared library dependencies, and outputs a list of Debian package names that provide those libraries. It fulfills the same role as [dpkg-shlibdeps](https://manpages.debian.org/stable/dpkg-dev/dpkg-shlibdeps.1.en.html) but can be used as a standalone tool instead of being tied to the official Debian package building process. This means that Debendable can be used in combination with [fpm](https://github.com/jordansissel/fpm) or other packaging tools.

## Usage

```bash
# Scan a single executable or library
debendable PATH_TO_EXECUTABLE_OR_LIBRARY

# Scan all executables and libraries in a directory
debendable PATH_TO_DIRECTORY
```

Example:

```
$ debendable /bin/bash
libtinfo6
libc6
```
