
# Understanding shared library dependency scanning

This article explains how we scan executables and libraries for their required shared libraries and map those libraries to the correct Debian packages, ensuring that everything runs as expected.

Executables and libraries are both in the [ELF format](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format), so for the remainder of this article we'll call them "ELF files".

## Extracting shared library dependencies

The first step in scanning an ELF file is to figure out which shared libraries it depends on. In Linux, these dependencies are listed directly in the ELF headers under the "NEEDED" section. These are the libraries that the ELF file will attempt to load when it's run.

To extract this information, we use the `objdump -p` command (part of GNU binutils). Here's an example:

```bash
sudo apt install binutils # if you don't have it yet
objdump -p my_elf_file | grep NEEDED
```

This will output something like:

```
  NEEDED               libfoo.so.1
  NEEDED               libc.so.6
```

In this case, `my_elf_file` directly requires `libfoo.so.1` and `libc.so.6` to be present on the system.

### Objdump over ldd

Another tool to view an ELF file's dependencies is `ldd`. We don't use it because it's recursive — it not only lists the immediate dependencies but also any transitive dependencies. While this is useful in some scenarios, it's not what we need here. We only care about the direct dependencies of the ELF file, which is what `objdump -p` gives us.

## Mapping libraries to Debian packages

For each identified the library dependency, we map them to the corresponding Debian packages. By querying the system’s package metadata, we can figure out which package provides each library. We can use `dpkg -S`. For example:

```bash
dpkg -S libfoo.so.1
```

The output might look like:

```
libfoo1:amd64: /usr/lib/x86_64-linux-gnu/libfoo.so.1
# -OR-
libfoo1: /usr/lib/x86_64-linux-gnu/libfoo1.so.1
```

This tells us that `libfoo.so.1` is provided by the `libfoo1` package with AMD64 architecture. The architecture part may be omitted though.

## Version constraints

Libraries change over time as new versions are released, often adding new functionality. Sometimes, ELF files depend on specific functions or variables (symbols) that may only be available in certain versions of a library. So we must also infer version constraints for the identified dependency packages. This process involves scanning symbol files.

Let's say our ELF file uses a function called `hail_taxi_with_discount` from the library `libtaxi.so.1`, packaged by the `supertaxi` package. However, `hail_taxi_with_discount` was only introduced in version Supertaxi 1.2. So we'll want to infer a dependency on `supertaxi (>= 1.2)`.

### Symbols files

How can we know which version of Supertaxi introduced `hail_taxi_with_discount`? By scanning the Supertaxi symbols file.

Symbols files are part of [the Debian symbols system](https://www.debian.org/doc/debian-policy/ch-sharedlibs.html#the-symbols-system). They are automatically generated during Debian's official packaging process. A symbols file lists all the symbols a library exports and the minimum version of the package that provides each symbol.

Symbols files are stored in the `/var/lib/dpkg/info/` directory. The files are named after the package and have a `.symbols` extension. For example:

```
/var/lib/dpkg/info/supertaxi.symbols
```

The file format looks like this:

```
libtic.so.6 libtinfo6 #MINVER#
| libtinfo6 #MINVER#, libtinfo6 (<< 6.2~)
* Build-Depends-Package: libncurses-dev
 NCURSES6_TIC_5.0.19991023@NCURSES6_TIC_5.0.19991023 6
 NCURSES6_TIC_5.1.20000708@NCURSES6_TIC_5.1.20000708 6
 ...
libtinfo.so.6 libtinfo6 #MINVER#
| libtinfo6 #MINVER#, libtinfo6 (<< 6.2~)
* Build-Depends-Package: libncurses-dev
 BC@NCURSES6_TINFO_5.0.19991023 6
 COLS@NCURSES6_TINFO_5.0.19991023 6
 ...
```

The first line specifies the library soname (libtic.so.6) for which symbols will follow. Lines like "NCURSES6[...] 6" specify the symbol name, and the minimum package version that provides that symbol.

A package can contain multiple libraries. Since there is only one symbols file per package, a symbols file can specify symbols for more than one library. You can see this through the fact that the example also mentions "libtinfo.so.6".

To learn more about the file format, see [the Debian Policy Manual](https://www.debian.org/doc/debian-policy/ch-sharedlibs.html#the-symbols-file-format).

## Alternative dependencies

Sometimes, multiple packages can satisfy the same library dependency. For example, both `libfoo1` and `libfoofork1` might provide `libfoo.so.1`. In cases like this, we express the dependency as an alternative, meaning that either package will satisfy the requirement.

Here's an example of how alternative dependencies are expressed:

```
libfoo1 | libfoofork1
```

This indicates that the system can install either `libfoo1` or `libfoofork1` to satisfy the dependency on `libfoo.so.1`.

If a specific version of the library is needed, the version constraint can be applied to the relevant package. For example:

```
libfoo1 (>= 1.2) | libfoofork1
```

This ensures that the system installs `libfoo1` version 1.2 or higher, but will also accept `libfoofork1` if it's available.
