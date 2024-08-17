
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
libfoo1: /usr/lib/x86_64-linux-gnu/libfoo.so.1
```

This tells us that the `libfoo1` package provides `libfoo.so.1`.

## Version constraints

Libraries change over time as new versions are released, often adding new functionality. Sometimes, ELF files depend on specific functions or variables (symbols) that may only be available in certain versions of a library. So we must also infer version constraints for the identified dependency packages. This process involves scanning symbol files.

Let's say our ELF file uses a function called `foo_function`, provided by `libfoo.so.1`, packaged by the `libfoo1` package. However, `foo_function` was only introduced in version 1.2 of `libfoo1`. So we'll want to infer a dependency on "libfoo1 (>= 1.2)".

Debian’s solution to this is symbols files, which track which symbols are introduced in which versions of a library. These files allow us to accurately declare dependencies that ensure the correct version of the library is installed.

### Example of Versioned Dependencies

Let's assume `foo_function` was introduced in version 1.2 of `libfoo1`. The dependency would look something like this:

```
libfoo1 (>= 1.2)
```

This ensures that version 1.2 or higher of `libfoo1` is installed, preventing any runtime issues related to missing symbols.

## Alternative Dependencies

Sometimes, multiple packages can satisfy the same library dependency. For example, both `libfoo1` and `libfoo1-dev` might provide `libfoo.so.1`. In cases like this, we express the dependency as an alternative, meaning that either package will satisfy the requirement.

### Example of Alternative Dependencies

Here's an example of how alternative dependencies are expressed:

```
libfoo1 | libfoo1-dev
```

This indicates that the system can install either `libfoo1` or `libfoo1-dev` to satisfy the dependency on `libfoo.so.1`.

If a specific version of the library is needed, the version constraint can be applied to the relevant package. For example:

```
libfoo1 (>= 1.2) | libfoo1-dev
```

This ensures that the system installs `libfoo1` version 1.2 or higher, but will also accept `libfoo1-dev` if it's available.

## Final Dependency Resolution

After identifying the required libraries and their corresponding Debian packages, and handling version constraints and alternative dependencies, the system generates a final list of dependencies. This list is ready to be interpreted by a package manager like `apt`, ensuring that all necessary libraries are installed when your executable runs.

Here's what a final set of dependencies might look like:

```
libfoo1 (>= 1.2), libc6 (>= 2.27), libbar1 | libbar1-dev
```

This tells the package manager exactly which packages and versions need to be installed to ensure that the executable has access to the libraries it needs at runtime.

## A Closer Look at Symbols and Symbols Files

### What Are Symbols?

Symbols are the individual functions, variables, or data fields that a shared library provides to other programs. When an executable is linked to a shared library, it uses these symbols. For example, the `malloc()` function is a symbol provided by `libc.so.6`.

If the required symbols are not present in the version of the library available on the system, the executable may fail to run. That's why it's important to keep track of which versions of a library provide which symbols.

### How Are Symbols Files Generated?

Symbols files are automatically generated during the packaging of a Debian library. These files list all the symbols the library exports and the minimum version of the package that provides each symbol. This allows us to declare precise dependencies on a library.

For example, if a new function `bar_function` was added in version 1.3 of `libbar1`, the symbols file will record that `bar_function` is available starting from version 1.3. Any executable that uses `bar_function` will depend on `libbar1 (>= 1.3)`.

### Where Are Symbols Files Stored?

Symbols files are stored in the `/var/lib/dpkg/info/` directory. The files are named after the package and have a `.symbols` extension. For example:

```
/var/lib/dpkg/info/libfoo1.symbols
```

These files play a crucial role in managing versioned dependencies and ensuring that the correct versions of libraries are installed.
