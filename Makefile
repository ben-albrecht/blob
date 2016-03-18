all: blob

blob: blob.chpl inputGen
	chpl blob.chpl -o blob

inputGen: inputGen.chpl
	chpl inputGen.chpl -o inputGen

clean:
	rm -f inputGen blob

