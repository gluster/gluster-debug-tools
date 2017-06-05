**1. Aim :**

This script is target to identify reference leaks in glusterfs.

**2. Necessity of the script** :

Currently if we suspect any leak in glusterfs, we captures the state of
the disk using state dump and checks which xlator is leaking. But to
detect which code path is leaking is difficult in case of ref
leaks.Whenever any process requires memory, it is given from memory pool
and referencing function returns the allocated memory to the caller
function but there is no dedicated owner of that memory. So this makes
it harder to debug from which code path this memory is leaking.

Using mem pools improves performance but makes it difficult to track the
allocation or freeing data structures.

While working on this issue, the main challenge was to how to approach
for this, possible approaches were to put loggers in the source code and
analyze it or the easy way is to use some debugger tool. If we go with
former approach, this means we are changing the source code of a
particular version. What if a user issue of some another version came
up? So to make useful for all the versions, i adopted this approach of
writing a common script for all versions.

**3. What is System Tap and why we are using this?**

It’s a dynamic method of monitoring and tracing the operations of a
running Linux kernel. It provides infrastructure for detailed analysis
of running linux kernel so that it can be analyzed deeply. For this, it
provides command line interface and scripting language.

Just to provide a hint at how useful user space tracing is, here are
some situations where SystemTap can provide more help than other user
application tracers and debuggers such as strace, ltrace, and gdb:

1.  Giving an integrated view of events in the kernel and selected
    > user applications.

2.  Probing of multi-threaded applications.

3.  Probing multi-process applications—including client/server
    > applications where the client and server processes
    > execute independently.

4.  Probing while running the application at or near full speed.

5.  Surgical probing, where a hand-written SystemTap script can provide
    > the required precision, in terms of events and functions probed
    > and data reported, that strace and other similar tools cannot.

It does not require that the kernel be reconfigured, recompiled and
reinstalled in order to capture data such as the value of specific
variables. Because of this characteristic, it is also used in production
servers to help find errors that are not easily reproducible, in a
transparent and non-disruptive manner. It does not require that the
server be stopped or reinitialized. Because of all these features, it is
fairly useful for this issue.

**4. How to use the script ?**

The stap script is used for analyzing the leaks. This
is wrapped around by a shell script which will
ask user for certain information and then run the stap script for doing
its task.

The script supports interactive as well as non-interactive mode.

1. For interactive mode run :
./wrap-for-leakscript.sh

It will ask a few things from user like the target function name which
you need to probe, process id, time for probing,etc.

You will see something like this :

Enter the no. for the function which you wants to probe. Press

1\. dict\_ref

2\. inode\_ref

3\. fd\_ref

1:

Enter Process Id :

3860

Enter the output filename :

(Default path for output file is : /var/run/gluster/leak-output/ )

dict-leak1

Enter probing time interval in minutes :

( Default is 15 minutes )

5

2. For non-interactive mode, you can do :
./wrap-for-leakscript.sh -h
You will see a usage message :
usage: ./wrap-for-leakscript.sh -f function_name -p pid [-t time-interval]
Here args for -f and -p are complusory where as -t is optional, by default
time-interval is 15 minutes.
Note : Time interval should be in minutes.

And then script starts executing.

After running the script, perform io’s. It should be taken care that the
time interval should be large enough that all io’s are done in that.

**4.1 What’s going on in background when stap script is running?**

System tap executes the script in five rounds/passes.

The stap command which is running in background looks something like
this :

stap -d /usr/local/lib/glusterfs/3.12dev/xlator/cluster/dht.so

-d /usr/local/lib/glusterfs/3.12dev/xlator/cluster/afr.so

-d /usr/local/lib/glusterfs/3.12dev/xlator/protocol/client.so

-d /usr/local/lib/glusterfs/3.12dev/xlator/debug/io-stats.so

-d /usr/local/lib/libgfrpc.so.0.0.1 -d
/usr/local/lib/glusterfs/3.12dev/xlator/meta.so

-d /usr/local/lib/glusterfs/3.12dev/rpc-transport/socket.so

-d /usr/local/lib/glusterfs/3.12dev/xlator/mount/fuse.so

-d /usr/lib64/libpthread-2.24.so -d /usr/lib64/libc-2.24.so

-d /usr/local/lib/glusterfs/3.12dev/xlator/performance/io-threads.so

-g --suppress-time-limits -DMAXSTRINGLEN=900 -S 5,100

-o /var/run/gluster/leak-output/dict-leak1 -v /root/ex/test-dumb.stp

-x 3860 dict\_ref dict\_unref 300

Command uses certain options and arguments:

-d : System tap requires information of these modules to be loaded into
kernel space module. --suppress-time-limits : To disable MAXACTION ,
which is maximum no. of statements to execute when a probe handler hits
(default value : 1000) (It require guru mode i.e. -g)

The rest options can be checked on stap man page. (man stap)

**Concept of script** : In glusterfs when any process is using memory
from memory pool, it simply calls ref/unref function, which keeps a
count of no. of times it is being referenced or dereferenced. When this
count is zero,this memory is put back into memory pool. The script is
capturing this variable and storing tracebacks every time when it is
used by any function. If the value is non-zero, it means that there
would be a possible leak, which needs to be analyzed.

Output : You will see the following when script runs :

Pass 1: parsed user script and 479 library scripts using
247904virt/50208res/7628shr/42752data kb, in 140usr/20sys/157real ms.

Pass 2: analyzed script: 3 probes, 6 functions, 0 embeds, 7 globals
using 251512virt/55104res/8688shr/46360data kb, in 30usr/0sys/24real ms.

Pass 3: using cached
/root/.systemtap/cache/a3/stap\_a3afa5f8e7d6cc1b8b20430003e866bb\_6194.c

Pass 4: using cached
/root/.systemtap/cache/a3/stap\_a3afa5f8e7d6cc1b8b20430003e866bb\_6194.ko

Pass 5: starting run.

**4.2 What are these Five passes?**

The five passe flow can be understand easily by the following :

![alt text](https://github.com/SonaArora/gluster-debug-tools/blob/master/systemtap-processing-steps.png){width="3.5989588801399823in"
height="3.3933038057742784in"}

The language is derived from dtrace and awk concepts. It describes an
association of handler subroutines with probe points. Probe points are
abstract names given to identify a particular place in kernel/user code,
or a particular event (timers) that may occur at any time.

Pass 1-2 Parse the script and the code is checked for semantic and
syntax errors. Any tapset reference is imported. Debug data provided via
debuginfo packages are read to find addresses for functions and
variables referenced in the script.

Pass 3 Translate the script into C code.

Pass 4 Compile the translated C code and create a kernel module.

Pass 5 Insert the module in the kernel.

Once the module is loaded, probes are inserted at proper locations. From
now on whenever a probe is hit, handler for that probe is called.

**5. Analyze Output**

The script runs and stores tracebacks from stack for every call to
ref/unref functions. If there is a leak all tracebacks corresponding to
leaked pointer is shown in output.

For instance, the output looks something like this :

ROUND : 0

Net ref counts for each ptr :

7fc7e0003210 : 1

Ref Traces :

ptr : 7fc7e0003210

dict\_ref+0xc \[libglusterfs.so.0.0.1\]

dict\_new+0x31 \[libglusterfs.so.0.0.1\]

dht\_rmdir\_opendir\_cbk+0x1cd \[dht.so\]

client3\_3\_opendir\_cbk+0x5c2 \[client.so\]

rpc\_clnt\_handle\_reply+0x1b7 \[libgfrpc.so.0.0.1\]

rpc\_clnt\_notify+0x2bc \[libgfrpc.so.0.0.1\]

rpc\_transport\_notify+0x10f \[libgfrpc.so.0.0.1\]

socket\_event\_poll\_in+0x6e \[socket.so\]

socket\_event\_handler+0x26c \[socket.so\]

event\_dispatch\_epoll\_handler+0x233 \[libglusterfs.so.0.0.1\]

event\_dispatch\_epoll\_worker+0x2af \[libglusterfs.so.0.0.1\]

0x7fc801ef85ca \[libpthread-2.23.so+0x75ca\]


ptr : 7fc7e0003210

dict\_ref+0xc \[libglusterfs.so.0.0.1\]

dht\_rmdir\_opendir\_cbk+0x38f \[dht.so\]

client3\_3\_opendir\_cbk+0x5c2 \[client.so\]

rpc\_clnt\_handle\_reply+0x1b7 \[libgfrpc.so.0.0.1\]

rpc\_clnt\_notify+0x2bc \[libgfrpc.so.0.0.1\]

rpc\_transport\_notify+0x10f \[libgfrpc.so.0.0.1\]

socket\_event\_poll\_in+0x6e \[socket.so\]

socket\_event\_handler+0x26c \[socket.so\]

event\_dispatch\_epoll\_handler+0x233 \[libglusterfs.so.0.0.1\]

event\_dispatch\_epoll\_worker+0x2af \[libglusterfs.so.0.0.1\]

0x7fc801ef85ca \[libpthread-2.23.so+0x75ca\]


ptr : 7fc7e0003210

dict\_ref+0xc \[libglusterfs.so.0.0.1\]

dht\_rmdir\_opendir\_cbk+0x38f \[dht.so\]

client3\_3\_opendir\_cbk+0x5c2 \[client.so\]

rpc\_clnt\_handle\_reply+0x1b7 \[libgfrpc.so.0.0.1\]

rpc\_clnt\_notify+0x2bc \[libgfrpc.so.0.0.1\]

rpc\_transport\_notify+0x10f \[libgfrpc.so.0.0.1\]

socket\_event\_poll\_in+0x6e \[socket.so\]

socket\_event\_handler+0x26c \[socket.so\]

event\_dispatch\_epoll\_handler+0x233 \[libglusterfs.so.0.0.1\]

event\_dispatch\_epoll\_worker+0x2af \[libglusterfs.so.0.0.1\]

0x7fc801ef85ca \[libpthread-2.23.so+0x75ca\]

------

Unref Traces:

ptr : 7fc7e0003210

dict\_unref+0xc \[libglusterfs.so.0.0.1\]

dht\_local\_wipe+0x65 \[dht.so\]

dht\_rmdir\_readdirp\_done+0x10b \[dht.so\]

dht\_rmdir\_readdirp\_cbk+0x175 \[dht.so\]

client3\_3\_readdirp\_cbk+0x50f \[client.so\]

rpc\_clnt\_handle\_reply+0x1b7 \[libgfrpc.so.0.0.1\]

rpc\_clnt\_notify+0x2bc \[libgfrpc.so.0.0.1\]

rpc\_transport\_notify+0x10f \[libgfrpc.so.0.0.1\]

socket\_event\_poll\_in+0x6e \[socket.so\]

socket\_event\_handler+0x26c \[socket.so\]

event\_dispatch\_epoll\_handler+0x233 \[libglusterfs.so.0.0.1\]

event\_dispatch\_epoll\_worker+0x2af \[libglusterfs.so.0.0.1\]

0x7fc801ef85ca \[libpthread-2.23.so+0x75ca\]

ptr : 7fc7e0003210

dict\_unref+0xc \[libglusterfs.so.0.0.1\]

dht\_local\_wipe+0x65 \[dht.so\]

dht\_rmdir\_readdirp\_done+0x10b \[dht.so\]

dht\_rmdir\_readdirp\_cbk+0x175 \[dht.so\]

client3\_3\_readdirp\_cbk+0x50f \[client.so\]

rpc\_clnt\_handle\_reply+0x1b7 \[libgfrpc.so.0.0.1\]

rpc\_clnt\_notify+0x2bc \[libgfrpc.so.0.0.1\]

rpc\_transport\_notify+0x10f \[libgfrpc.so.0.0.1\]

socket\_event\_poll\_in+0x6e \[socket.so\]

socket\_event\_handler+0x26c \[socket.so\]

event\_dispatch\_epoll\_handler+0x233 \[libglusterfs.so.0.0.1\]

event\_dispatch\_epoll\_worker+0x2af \[libglusterfs.so.0.0.1\]

0x7fc801ef85ca \[libpthread-2.23.so+0x75ca\]

-----------

From the above traces , we can see that 7fc7e0003210 is leaking. This
ptr is taking memory from mem pool, dht\_rmdir\_opendir\_cbk is calling
dict\_new() and dereferencing it thrice , thus three times its calling
dict\_ref(). But correspondingly, there are only two calls to
dict\_unref() from dht\_rmdir\_readdirp\_done(). Thus it clearly shows
dict\_unref() is missing from dht\_rmdir\_opendir\_cbk().

Note : This leak is manually created to test the script.

**Things to keep in mind :**

1.  Performance xlators are creating xattr’s when new file is created.
    > This makes call to referencing function.The counter unref call
    > (deleting xattr’s) would be when the file is deleted. So the count
    > may be positive in such case, depending on the fops. But it’s not
    > a leak. So if you don’t want to trace performance xlators,
    > disable it.

2.  Inode case: Root inode will be in active list of inode table. So
    > refcount for root inode will always be positive.

**Future activity :**

If the script needs to be utilized for versions other than
glusterfs-3.12, the wrapper script can be made smarter for some cases
such as it would automatically fetch modules for the probed process
required for debugging from the graph vol files.
