all: blob

OBJECTS = blob inputGen distributed
REALS = blob_real inputGen_real distributed_real

%: %.chpl
	chpl $< -o $@

clean:
	rm -f ${OBJECTS}
	rm -f ${REALS}
