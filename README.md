# Debian package shared library dependencies inferer

Debendencies scans executables and shared libraries for their shared library dependencies, and outputs a list of Debian package names that provide those libraries. It fulfills the same role as [dpkg-shlibdeps](https://manpages.debian.org/stable/dpkg-dev/dpkg-shlibdeps.1.en.html) but can be used as a standalone tool instead of being tied to the official Debian package building process. This means that Debendencies can be used in combination with [fpm](https://github.com/jordansissel/fpm) or other packaging tools.

## Usage

```bash
# Scan a single executable or library
debendencies PATH_TO_ELF_FILE

# Scan all executables and libraries in a directory
debendencies PATH_TO_DIRECTORY
```

Example:

```
$ debendencies /bin/bash
libtinfo6
libc6
```
