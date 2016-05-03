use Help;
use Distributed;
use InputGen;

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
  var Grid = if filename.isEmptyString() then genGrid(n)
             else readGrid(filename);

  writeln(Grid);

  //
  // Generate general image of pixels from input data
  //

  var globalImage = genImage(Grid);

  var image = if comm == 'none' then globalImage
              else distributeArray(globalImage);

  if comm != 'none' then
    printLocality(image);
  //
  // Blob Extraction
  //

  var blobGrid = if comm == 'none' then blobExtractionSerial(image)
                 else blobExtraction(image);

  //prettyPrint(blobGrid);
}

/* Read in grid from file */
proc readGrid(filename) {

  // Read from file if file is provided
  var infile: file;

  infile = open(filename, iomode.r);
  var input  = infile.reader();

  var N = len(infile.lines());
  var Dom = {1..N, 1..N};
  var Grid : [Dom] int;

  input.read(Grid);
  input.close();

  return Grid;
}


proc blobExtraction(image) {
  var globalBlob: [image.domain] uint(8);
  var blobGrid = distributeArray(globalBlob);

  var L = {0..numLocales};
  var localeDom = L dmapped Block(L);
  var maxLabels: [localeDom] uint(8) = 0;

  coforall loc in Locales {
    on loc {
      var currentLabel: uint(8);
      var stack = new Stack();
      //var localImage => image._value.locArr[here.id].myElems;
      var localImage => image._value.myLocArr.locDom.myBlock;
      for (i, j) in localImage {
        var x, y: int;
        if !blobGrid[i, j] {
          currentLabel += 1;
          blobGrid[i, j] = currentLabel;
          stack.push((i, j));
          do {
            (x, y) = stack.pop();
            for (k,l) in neighbors(x, y) {
              if !blobGrid[k, l] {
                if image[x, y].foreground(image[k, l]) {
                  blobGrid[k, l] = currentLabel;
                  stack.push((k, l));
                }
              }
            }
          } while !stack.isEmpty();
        }
        maxLabels[here.id] = currentLabel;
      }
    }
  }

  // Increment locales by maxLabels[]
  syncLabels(blobGrid, maxLabels);

  //mapOverlaps(image);

  return blobGrid;
}


proc syncLabels(ref blobGrid, maxLabels) {
  coforall loc in Locales[1..Locales.size - 1] {
    on loc {
      var localBlob => blobGrid._value.myLocArr.locDom.myBlock;
      forall (i, j) in localBlob {
        blobGrid[i, j] += maxLabels[here.id-1];
      }
    }
  }
}


proc blobExtractionSerial(image) {
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


/* Count the length of an iterable object */
proc len(iterable) {
  var count = 0;
  for iteration in iterable do count += 1;
  return count;
}


proc prettyPrint(blobGrid) {
  var blobPretty : [blobGrid.domain] string;
  writeln();
  forall (i, j) in blobGrid.domain {
    // Represent each number as an ascii char between 32 and 126
    blobPretty[i, j] = "%c".format((blobGrid[i, j] % 95) + 32);
  }
  writeln(blobPretty);
}


/* Help function */
proc printHelp(program) {
  writeln(program, " performs connected component analysis on an input file");
}


/* Record for holding pixel data, or any other data that fills the grid */
record pixel {
  // Using a dummy value instead of rgb for now
  var value : int = -1;

  // Function to determine if another pixel is in the 'foreground'
  proc foreground(p : pixel): bool {
    return p.value == value;
  }
}


/* Node containing data and next node for Stack class */
class Node {
  var data: 2*(int);
  var next: Node;
}


/* Really simple stack data structure */
class Stack {

  var head : Node;

  proc push(data) {
    var n = new Node(data, head);
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
