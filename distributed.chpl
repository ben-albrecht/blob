use BlockDist;

module Distributed {

  /* Create and return a distributed array */
  proc distributeArray(globalArray) {

    // Reshape default array, Locales, into '1 x numLocales' 2D localeArray
    var localeDom = {1..numLocales, 1..1};
    var localeArray : [localeDom] locale = reshape(Locales, localeDom);

    const Dom = globalArray.domain dmapped Block(globalArray.domain, targetLocales=localeArray);
    var Array : [Dom] globalArray.eltType;

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
        Array._value.myLocArr.locDom.myBlock = thisDomainExpanded;
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


  /* Map overlap of each locale's array to the next */
  proc mapOverlaps(ref Array) {

    var overlapDom: domain(int);
    var overlapMap: [overlapDom] int;

    for loc in Locales[0.. # Locales.size - 1] {
      on loc {

        // Would be cool if localSubdomain for localSubarray existed
        // Also, localSubdomain(locid=here.id)
        var nextArray => Array._value.locArr[here.id+1, 0].myElems;
        const thisArray => Array._value.locArr[here.id, 0].myElems,
        nextDomain = nextArray.domain,
        thisDomain = thisArray.domain; // Same as Array.localSubdomain()

        var i = thisDomain.last(1);

        for j in thisDomain.first(2)..thisDomain.last(2) {
          var oldValue = nextArray[i, j],
          newValue = thisArray[i, j];
          overlapMap[oldValue] = newValue;
        }

        for (i,j) in nextDomain {
          var oldValue = nextArray[i, j];
          if overlapMap.domain.member(oldValue) {
           nextArray[i, j] = overlapMap[oldValue];
          }
        }
      }
    }
  }


  /* Printing tools */
  proc printLocality(const Array) {
    var ownership : [Array.domain] int = -1;

    for loc in Locales {
      on loc {
        writeln('Locale: ', here.id, ' owns ', Array.localSubdomain());
        for (i,j) in Array.localSubdomain() {
          ownership[i,j] = here.id;
        }
      }
    }

    writeln(ownership);
  }

  proc printLocalValues(const Array) {
    // Atomic to ensure print order
    var id : atomic int;
    id.write(0); // I believe default is 0?

    forall loc in Locales {
      on loc {
        id.waitFor(here.id);
        writeln('Locale ', here.id, ' Array[',Array.localSubdomain(),'] = ');
        writeln(Array._value.locArr[here.id, 0].myElems);
        id.add(1);
      }
    }
  }

}
