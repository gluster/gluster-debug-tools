CFLAGS := -g $(shell pkg-config --cflags glusterfs-api)
LDLIBS := $(shell pkg-config --libs-only-l glusterfs-api)
LDFLAGS := $(shell pkg-config --libs-only-L glusterfs-api)

PROGRAMS := gfapi-load-volfile

all: $(PROGRAMS)

clean:
	$(RM) $(PROGRAMS)
