#SUN3
#MACHINE = M68
#DEFS = -DBSD -DSUN3
#CFL = -n -Bstatic -f68881
#ASMBLR = as

#SONY
#MACHINE = M68
#DEFS =  -DBSD
#CFL =
#ASMBLR = /mnt/brown/toe/gas/a68  # the GNU assembler, that is

#SUN4
#MACHINE = SPARC
#DEFS = -DBSD
#CFL = -n -Bstatic
#ASMBLR = as

#ENCORE
#MACHINE = NS32
#DEFS =  -DBSD
#CFL =
#ASMBLR = as -j

#NEXT
#MACHINE = M68
#DEFS = -DBSD -DMACH
#CFL =
#ASMBLR = as

#VAXBSD
#MACHINE = VAX
#DEFS = -DBSD
#CFL = 
#ASMBLR = as

#VAXV9
#MACHINE = VAX
#DEFS = -DV9
#CFL = 
#ASMBLR = as

DEFINES = -D$(MACHINE) $(DEFS)
#CFLAGS = -g $(CFL) $(DEFINES)
CFLAGS = -O $(CFL) $(DEFINES)

# Other possible #define's:
# PROFILE:  for a run which counts allocs.
# GCDEBUG:  print extra information during garbage collection,
#	    examine the to_space after a collection for stray pointers,
#	    and check create_b and create_s for zero allocation.
# GCPROFILE: for a run which prints out cumulative garbage collector
#	     information as it exits.

run: run.o gc.o callgc.o prim.o prof.o export.o objects.o cstruct.o trace.o allmo.o
	cc $(CFLAGS) -o run run.o gc.o callgc.o prim.o prof.o export.o objects.o cstruct.o trace.o allmo.o

allmo.o: STUB.allmo.s
	/lib/cpp $(DEFINES) STUB.allmo.s > allmo.s
	$(ASMBLR) -o allmo.o allmo.s
#	linkdata >allmo.o

linkdata: linkdata.c
	cc $(CFLAGS) -o linkdata linkdata.c

prim.o: $(MACHINE).prim.s tags.h prof.h ml.h prim.h
	/lib/cpp $(DEFINES) $(MACHINE).prim.s > prim.s
	$(ASMBLR) -o prim.o prim.s

callgc.o objects.o gc.o run.o trace.o: descriptor.h tags.h

callgc.o run.o export.o objects.o: ml.h

prof.o: prof.h

clean:
	rm -f *.o lint.out prim.s linkdata allmo.s

lint:
	lint $(DEFINES) run.c gc.c callgc.c prof.c export.c objects.c cstruct.c trace.c | tee lint.out
