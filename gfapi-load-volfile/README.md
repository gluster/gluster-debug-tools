# Debugging tools for gfapi

These tools aid the development of gfapi and help fixing bugs.

## gfapi-load-volfile

This small tool loads the graph specified in the passed `.vol` file, and
destroys it again.

When running this with a debug build (`./configure --enable-debug`) of
GlusterFS, memory leaks for selected xlators can be found. The debug builds are
needed to disable the memory pool functionality, otherwise `valgrind` will get
(more) confused and is unable to track the memory allocations.

To build debug packages for CentOS-7, this command can be used:

    $ make distclean ; rm -rf autom4te.cache *.gz *.rpm ; ./autogen.sh && \
        ./configure --enable-debug && make dist && \
        rpmbuild -ts --define "_srcrpmdir $PWD" *.gz && \
        mock -r epel-7-x86_64 --rebuild --with=debug *.rpm

To build the test program, just run `make`.

There are different `.vol` files for testing in this directory, they all have
the `*.vol` filename extension. Some xlators need a few configuration options
set, the details are mentioned in the comments in each of the `.vol` files.

The execution then looks like:

    $ ./gfapi-load-volfile sink.vol

The log for this gfapi application can be found in `gfapi-load-volfile.log`.

For further debugging with Valgrind, a command like this is useful:

    $ valgrind --leak-check=full --show-leak-kinds=all ./gfapi-load-volfile sink.vol
