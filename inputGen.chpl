/* Generate random image with 0s and 1s for blob detection analysis */
use Help;
use Random;

config const outputfname: string = "";
config const order: int = 10;

proc main(args: [] string) {
  const program = args[0];
  for arg in args {
    writeln(arg);
    if arg == "--help" {
      printUsage();
      printHelp(program);
      exit();
    }
  }

  // Write to stdout unless a filename is provided
  var output = stdout;
  var outfile : file;

  if ! outputfname.isEmptyString() {
    outfile = open(outputfname, iomode.cw);
    output = outfile.writer();
    writeln("Writing data to ", outputfname);
  }

  var Grid = genGrid(order);

  output.write(Grid);

}

proc genGrid(N) {

  // Create a random binary 2D array
  var random = new RandomStream(eltType=int);
  var Dom = {1..N, 1..N};
  var Grid : [Dom] int;

  forall (i, j) in Dom {
    Grid[i, j] = random.getNext(0,1);
  }

  return Grid;
}

proc printHelp(program) {
  writeln(program, " generates a 2D grid of numbers for input for blob detection");
}
