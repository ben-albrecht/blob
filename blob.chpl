use Help;
use BlockDist;

use inputGen;

config const filename: string;
config const n: int = 10;

// Less obnoxious variable name
param comm = CHPL_COMM;

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
  var globalGrid = if filename.isEmptyString() then genGrid(n)
             else then readGrid(filename)

  var Grid = if comm == 'none' then globalGrid 
             else distributeArray(globalGrid);

  writeln(Grid);

  //
  // Generate general image of pixels from input data
  //

  var image = genImage(Grid);

  //
  // Blob Extraction
  //

  var blobGrid = blobExtraction(image);

  writeln();
  prettyPrint(blobGrid);
}

/* Create and return a distributed array */
proc distributeArray(globalArray) {

  // Reshape default array, Locales, into '1 x numLocales' 2D localeArray
  var localeDom = {1..numLocales, 1..1};
  var localeArray : [localeDom] locale = reshape(Locales, localeDom);

  const Dom = globalArray.domain dmapped Block(globalArray.domain, targetLocales=localeArray);
  var Array : [Dom] int;

  addFluff(Array);

  assignArray(Array, globalArray);

  return Array;
}

/* Add row of fluff in 1 direction that overlaps with next locales domain */
proc addFluff(ref Array) {

  // Exclude last locale
  for loc in Locales[0.. # Locales.size - 1] {
    on loc {
      // Domain of this locale
      var thisDomain = Array._value.myLocArr.locDom.myBlock;
      // Expand row in 1 direction, overlapping with next locale
      var thisDomainExpanded = {thisDomain.first(1)..thisDomain.last(1)+1, thisDomain.first(2)..thisDomain.last(2)};
      // Update locale's copy of domain
      Array._value.myLocArr.locDom.myBlock = localDomExpanded;
    }
  }
}

/* Copy Array values */
proc assignArray(ref Array, globalArray) {
  // I don't think this is necessary.. but we'll find out
  forall loc in Locales {
    on loc {
      for (i, j) in Array.localSubdomain() {
        Array[i, j] = globalArray[i, j];
      }
    }
  }
}

proc readGrid(filename) {

  // Read from file if file is provided
  var infile: file;

  infile = open(filename, iomode.r);
  var input  = infile.reader();

  var N = numLines(infile);
  var Dom = {1..N, 1..N};
  var Grid : [Dom] int;

  input.read(Grid);
  input.close();

  return Grid;
}


proc numLines(filehandle) {
  var n = 0;
  for line in filehandle.lines() do n += 1;
  return n;
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
      } while !stack.isEmpty();
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


// LIFO
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
