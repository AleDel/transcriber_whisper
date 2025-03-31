class PatienceDiffJs {
  List<String> aLines;
  List<String> bLines;
  bool diffPlusFlag;
  List<Map<String, dynamic>> result = [];
  int deleted = 0;
  int inserted = 0;
  List<String> aMove = [];
  List<int> aMoveIndex = [];
  List<String> bMove = [];
  List<int> bMoveIndex = [];

  PatienceDiffJs(this.aLines, this.bLines, this.diffPlusFlag);

  Map<String, dynamic> patienceDiffJs() {
    recurseLCS(0, aLines.length - 1, 0, bLines.length - 1, null);

    if (diffPlusFlag) {
      return {
        'lines': result,
        'lineCountDeleted': deleted,
        'lineCountInserted': inserted,
        'lineCountMoved': 0,
        'aMove': aMove,
        'aMoveIndex': aMoveIndex,
        'bMove': bMove,
        'bMoveIndex': bMoveIndex,
      };
    }

    return {'lines': result, 'lineCountDeleted': deleted, 'lineCountInserted': inserted, 'lineCountMoved': 0};
  }

  Map<String, dynamic> patienceDiffPlusJs() {
    final difference = patienceDiffJs();

    // Verificar si las claves existen antes de usarlas
    List<String> aMoveNext = difference.containsKey('aMove') ? List<String>.from(difference['aMove']) : [];
    List<int> aMoveIndexNext = difference.containsKey('aMoveIndex') ? List<int>.from(difference['aMoveIndex']) : [];
    List<String> bMoveNext = difference.containsKey('bMove') ? List<String>.from(difference['bMove']) : [];
    List<int> bMoveIndexNext = difference.containsKey('bMoveIndex') ? List<int>.from(difference['bMoveIndex']) : [];

    difference.remove('aMove');
    difference.remove('aMoveIndex');
    difference.remove('bMove');
    difference.remove('bMoveIndex');

    int lastLineCountMoved = 0;

    do {
      List<String> aMove = List<String>.from(aMoveNext);
      List<int> aMoveIndex = List<int>.from(aMoveIndexNext);
      List<String> bMove = List<String>.from(bMoveNext);
      List<int> bMoveIndex = List<int>.from(bMoveIndexNext);

      aMoveNext.clear();
      aMoveIndexNext.clear();
      bMoveNext.clear();
      bMoveIndexNext.clear();

      final subDiff = PatienceDiffJs(aMove, bMove, false).patienceDiffJs();

      lastLineCountMoved = difference['lineCountMoved'];

      // Verificar si subDiff['lines'] es null antes de iterar
      if (subDiff['lines'] != null) {
        for (var i = 0; i < subDiff['lines'].length; i++) {
          final v = subDiff['lines'][i];

          if (0 <= v['aIndex'] && 0 <= v['bIndex']) {
            difference['lines'][aMoveIndex[v['aIndex']]]['moved'] = true;
            difference['lines'][bMoveIndex[v['bIndex']]]['aIndex'] = aMoveIndex[v['aIndex']];
            difference['lines'][bMoveIndex[v['bIndex']]]['moved'] = true;
            difference['lineCountInserted']--;
            difference['lineCountDeleted']--;
            difference['lineCountMoved']++;
          } else if (v['bIndex'] < 0) {
            aMoveNext.add(aMove[v['aIndex']]);
            aMoveIndexNext.add(aMoveIndex[v['aIndex']]);
          } else {
            bMoveNext.add(bMove[v['bIndex']]);
            bMoveIndexNext.add(bMoveIndex[v['bIndex']]);
          }
        }
      }
    } while (0 < difference['lineCountMoved'] - lastLineCountMoved);

    return difference;
  }

  Map<String, int> findUnique(List<String> arr, int lo, int hi) {
    final lineMap = <String, dynamic>{};

    for (var i = lo; i <= hi; i++) {
      final line = arr[i];

      if (lineMap.containsKey(line)) {
        lineMap[line]['count']++;
        lineMap[line]['index'] = i;
      } else {
        lineMap[line] = {'count': 1, 'index': i};
      }
    }

    lineMap.removeWhere((key, value) => value['count'] != 1);
    final result = <String, int>{};
    lineMap.forEach((key, value) {
      result[key] = value['index'];
    });
    return result;
  }

  Map<String, Map<String, int>> uniqueCommon(List<String> aArray, int aLo, int aHi, List<String> bArray, int bLo, int bHi) {
    final ma = findUnique(aArray, aLo, aHi);
    final mb = findUnique(bArray, bLo, bHi);
    final result = <String, Map<String, int>>{};
    ma.forEach((key, value) {
      if (mb.containsKey(key)) {
        result[key] = {'indexA': value, 'indexB': mb[key]!};
      }
    });
    return result;
  }

  List<Map<String, dynamic>> longestCommonSubsequence(Map<String, Map<String, int>> abMap) {
    final ja = <List<Map<String, dynamic>>>[];

    abMap.forEach((key, val) {
      var i = 0;
      while (ja.isNotEmpty && i < ja.length && ja[i].isNotEmpty && ja[i].last['indexB'] < val['indexB']!) {
        i++;
      }

      if (ja.length <= i) {
        ja.add([]);
      }
      // Creamos un nuevo mapa con las propiedades necesarias
      final newMap = <String, dynamic>{'indexA': val['indexA'], 'indexB': val['indexB']};

      if (0 < i) {
        newMap['prev'] = ja[i - 1].last; // Añadimos 'prev' al nuevo mapa
      }

      ja[i].add(newMap); // Añadimos el nuevo mapa a ja
    });

    final lcs = <Map<String, dynamic>>[];
    if (0 < ja.length) {
      var n = ja.length - 1;
      lcs.add(ja[n].last);

      while (lcs.last['prev'] != null) {
        lcs.add(lcs.last['prev']);
      }
    }

    return lcs.reversed.toList();
  }

  void addToResult(int aIndex, int bIndex) {
    if (bIndex < 0) {
      aMove.add(aLines[aIndex]);
      aMoveIndex.add(result.length);
      deleted++;
    } else if (aIndex < 0) {
      bMove.add(bLines[bIndex]);
      bMoveIndex.add(result.length);
      inserted++;
    }

    result.add({'line': 0 <= aIndex ? aLines[aIndex] : bLines[bIndex], 'aIndex': aIndex, 'bIndex': bIndex});
  }

  void addSubMatch(int aLo, int aHi, int bLo, int bHi) {
    // Match any lines at the beginning of aLines and bLines.
    while (aLo <= aHi && bLo <= bHi && aLines[aLo] == bLines[bLo]) {
      addToResult(aLo++, bLo++);
    }

    // Match any lines at the end of aLines and bLines, but don't place them
    // in the "result" array just yet, as the lines between these matches at
    // the beginning and the end need to be analyzed first.
    var aHiTemp = aHi;
    while (aLo <= aHi && bLo <= bHi && aLines[aHi] == bLines[bHi]) {
      aHi--;
      bHi--;
    }

    // Now, check to determine with the remaining lines in the subsequence
    // whether there are any unique common lines between aLines and bLines.
    //
    // If not, add the subsequence to the result (all aLines having been
    // deleted, and all bLines having been inserted).
    //
    // If there are unique common lines between aLines and bLines, then let's
    // recursively perform the patience diff on the subsequence.
    final uniqueCommonMap = uniqueCommon(aLines, aLo, aHi, bLines, bLo, bHi);
    if (uniqueCommonMap.isEmpty) {
      while (aLo <= aHi) {
        addToResult(aLo++, -1);
      }
      while (bLo <= bHi) {
        addToResult(-1, bLo++);
      }
    } else {
      recurseLCS(aLo, aHi, bLo, bHi, uniqueCommonMap);
    }

    // Finally, let's add the matches at the end to the result.
    while (aHi < aHiTemp) {
      addToResult(++aHi, ++bHi);
    }
  }

  void recurseLCS(int aLo, int aHi, int bLo, int bHi, Map<String, Map<String, int>>? uniqueCommonMap) {
    final x = longestCommonSubsequence(uniqueCommonMap ?? uniqueCommon(aLines, aLo, aHi, bLines, bLo, bHi));

    if (x.isEmpty) {
      addSubMatch(aLo, aHi, bLo, bHi);
    } else {
      if (aLo < x[0]['indexA'] || bLo < x[0]['indexB']) {
        addSubMatch(aLo, x[0]['indexA'] - 1, bLo, x[0]['indexB'] - 1);
      }

      for (var i = 0; i < x.length - 1; i++) {
        addSubMatch(x[i]['indexA'], x[i + 1]['indexA'] - 1, x[i]['indexB'], x[i + 1]['indexB'] - 1);
      }

      if (x.last['indexA'] <= aHi || x.last['indexB'] <= bHi) {
        addSubMatch(x.last['indexA'], aHi, x.last['indexB'], bHi);
      }
    }
  }
}
