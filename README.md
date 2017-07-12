Debugging Tools for Gluster
===========================

This repository contains different tools to debug Gluster and related projects.
Most users should have no need for these tools, they are only needed for
detailed troubleshooting, developer debugging or verification.


## gfapi-load-volfile

In order to detect memory leaks in a small environment where little xlators are
loaded and limited functions are called, `gfapi-load-volfile` can be used. This
small test application uses `libgfapi.so` to initialize and destroy a graph of
xlators. Combined with Valgrind, it is a very useful tool for detecting memory
leaks. More details about the usage of the tool and accompanied scripts are in
the [README.md](gfapi-load-volfile/README.md).

