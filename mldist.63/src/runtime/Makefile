#SUN3
#MACHINE = M68
#DEFS = -DBSD -DSUN3
#CFL = -n -Bstatic -f68881
#AS = as

#SONY
#MACHINE = M68
#DEFS =  -DBSD
#CFL =
#AS = /mnt/brown/toe/gas/a68  # the GNU assembler, that is

#SUN4
#MACHINE = SPARC
#DEFS = -DBSD
#CFL = -n -Bstatic
#AS = as

#ENCORE
#MACHINE = NS32
#DEFS =  -DBSD
#CFL =
#AS = as -j

#NEXT
#MACHINE = M68
#DEFS = -DBSD -DMACH
#CFL =
#AS = as

#VAXBSD
#MACHINE = VAX
#DEFS = -DBSD
#CFL = 
#AS = as

#VAXV9
#MACHINE = VAX
#DEFS = -DV9
#CFL = 
#AS = as

#
# this is needed by HPUX
#
SHELL=/bin/sh

DEFINES = -D$(MACHINE) $(DEFS)
#CFLAGS = -g $(CFL) $(DEFINES)
CFLAGS = -O $(CFL) $(DEFINES)

# Other possible #define's:
# GCDEBUG:  print extra information during garbage collection,
#	    examine the to_space after a collection for stray pointers,
#	    and check create_b and create_s for zero allocation.
# GCPROFILE: for a run which prints out cumulative garbage collector
#	     information as it exits.

MDEP	= $(MACHINE).dep

OBJS	= run.o run_ml.o callgc.o gc.o $(MDEP).o prim.o export.o timers.o \
	  ml_objects.o cfuns.o cstruct.o signal.o exncode.o malloc.o \
	  allmo.o

run:	$(OBJS)
	$(CC) $(CFLAGS) -o run $(OBJS)

#
# include file dependencies
#

callgc.o cfuns.o run_ml.o : cause.h

$(MACHINE).dep.o callgc.o cfuns.o export.o run.o signal.o timers.o : ml_os.h

signal.o : ml_signal.h

prim.o ml_objects.o : ml_state.h

$(MACHINE).dep.o callgc.o cfuns.o cstruct.o exncode.o gc.o \
ml_objects.o run.o run_ml.o signal.o timers.o : ml_types.h ml_state.h tags.h

$(MACHINE).dep.o prim.o callgc.o run_ml.o signal.o : request.h

export.o : tags.h


prim.o : $(MACHINE).prim.s tags.h
	 $(CPP) -DASM $(DEFINES) $(MACHINE).prim.s > prim.s
	 $(AS) -o prim.o prim.s

allmo.o : allmo.c tags.h ml_types.h ml_state.h

linkdata: linkdata.c tags.h
	$(CC) $(CFLAGS) -o linkdata linkdata.c

clean:
	rm -f *.o lint.out prim.s linkdata allmo.s run
