use Help;
use inputGen;

config const filename: string;
config const n: int = 10;

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

  //
  // Receive input data
  //

  /*
  // Read from file if file is provided
  var infile: file;

  infile = open(filename, iomode.r);
  var input  = infile.reader();

  writeln(input.type: string);
  */

  // Else get grid from inputGen

  var Grid = genGrid(n);

  writeln(Grid);

  //
  // Generate general image of pixels from input data
  //

  var image = genImage(Grid);

  //
  // Blob Extraction
  //

  var blobGrid = blobExtraction(image);

  //writeln();
  //writeln(blobGrid);
  writeln();
  prettyPrint(blobGrid);

}


proc prettyPrint(blobGrid) {
  var blobPretty : [blobGrid.domain] string;
  forall (i, j) in blobGrid.domain {
    // Represent each number as an ascii char between 32 and 126
    blobPretty[i, j] = "%c".format((blobGrid[i, j] % 95) + 32);
  }
  writeln(blobPretty);
}


proc blobExtraction(image) {
  var currentlabel : uint(8) = 0;
  var blobGrid : [image.domain] uint(8);
  var x, y : int;
  var stack = new Stack();

  for (i, j) in image.domain {
    if !blobGrid[i, j] {
      currentlabel += 1;
      blobGrid[i, j] = currentlabel;
      stack.push((i, j));
      do {
        (x, y) = stack.pop();
        for (k,l) in neighbors(x, y) {
          if !blobGrid[k, l] {
            if image[x, y].foreground(image[k, l]) {
              blobGrid[k, l] = currentlabel;
              stack.push((k, l));
            }
          }
        }
      } while ! stack.isEmpty();
    }
  }

  return blobGrid;
}


proc labelBlob(i, j, const image, ref blobGrid, currentlabel, currentpixel) {
  if blobGrid[i, j] == -1 {
    if currentpixel.foreground(image[i, j]) {
      blobGrid[i, j] = currentlabel;
      for (k,l) in neighbors(i, j) {
        labelBlob(k, l, image, blobGrid, currentlabel, image[i, j]);
      }
    }
  }
}


// Connectivity defined in this way
// Makes use of global n, and assume domain is {1..n}
iter neighbors(x, y) {
  if x+1 <= n then yield (x+1, y);
  if x-1 >= 1 then yield (x-1, y);
  if y+1 <= n then yield (x, y+1);
  if y-1 >= 1 then yield (x, y-1);
}


proc genImage(Grid) {
  var image : [Grid.domain] pixel;
  for (i, j) in Grid.domain {
    image[i, j] = new pixel(Grid[i,j]);
  }
  return image;
}


proc printHelp(program) {
  writeln(program, " performs connected component analysis on an input file");
}


// We use integer value as simple example (rather than rgb)
record pixel {
  var value : int = -1;

  // Function to determine if another pixel is in the foreground
  proc foreground(p : pixel): bool {
    return p.value == value;
  }
}


class node {
  var data: 2*(int);
  var next: node;
}


// LIFO linked list
class Stack {

  var head : node;

  proc push(data) {
    var n = new node(data, head);
    head = n;
  }

  proc pop() {
    var popped = head;
    head = popped.next;
    return popped.data;
  }

  proc isEmpty() {
    return head == nil;
  }

}