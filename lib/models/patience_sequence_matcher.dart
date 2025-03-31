import 'dart:math';

class PatienceSequenceMatcher<T> {
  final EqualityComparer<T> _equality;

  PatienceSequenceMatcher([EqualityComparer<T>? comparer]) : _equality = comparer ?? EqualityComparer<T>();

  /// Encuentra líneas únicas y comunes entre [a] y [b].
  ///
  /// Luego se ordenan según su aparición en [a], mientras se realiza un seguimiento del índice en [b].
  /// Finalmente, esa lista se ordena según un ordenamiento de paciencia y se extrae la subsecuencia común más larga.
  ///
  /// [a]: La primera lista de valores.
  /// [b]: La segunda lista de valores.
  /// [aLow]: El índice inicial en [a] (inclusivo).
  /// [bLow]: El índice inicial en [b] (inclusivo).
  /// [aHigh]: El índice final en [a] (exclusivo).
  /// [bHigh]: El índice final en [b] (exclusivo).
  ///
  /// Devuelve una lista de pares que representan la subsecuencia común más larga:
  /// (Índice del elemento en [a], Índice del elemento en [b]).
  Iterable<Pair> uniqueLcs(List<T> a, List<T> b, int aLow, int bLow, int aHigh, int bHigh) {
    print("uniqueLcs: aLow=$aLow, bLow=$bLow, aHigh=$aHigh, bHigh=$bHigh");
    final index = <T, NullablePair>{};
    final act = aHigh - aLow;
    final bct = bHigh - bLow;

    // Establecer index[line in a] = posición de la línea en a a menos que
    // a sea un duplicado, en cuyo caso se establece en null
    for (var i = 0; i < act; i++) {
      final line = a[aLow + i];
      print("uniqueLcs: index: i=$i, line=$line");
      if (index.containsKey(line)) {
        index[line] = index[line]!.setA(null);
        print("uniqueLcs: index: Duplicado encontrado: line=$line, index[line]=$index");
      } else {
        index[line] = NullablePair(i, null);
        print("uniqueLcs: index: Agregado: line=$line, index[line]=$index");
      }
    }
    print("uniqueLcs: index: $index");

    // Hacer btoa[i] = posición de la línea i en a, a menos que
    // esa línea no ocurra exactamente una vez en ambas,
    // en cuyo caso se establece en null
    final btoa = List<int?>.filled(bct, null);
    for (var i = 0; i < bct; i++) {
      final line = b[bLow + i];
      print("uniqueLcs: btoa: i=$i, line=$line");
      if (index.containsKey(line) && index[line]!.a != null) {
        if (index[line]!.b != null) {
          btoa[index[line]!.b!] = null;
          index[line] = index[line]!.setA(null);
          print("uniqueLcs: btoa: Duplicado encontrado en b: line=$line, btoa=$btoa, index[line]=$index");
        } else {
          index[line] = index[line]!.setB(i);
          btoa[i] = index[line]!.a;
          print("uniqueLcs: btoa: Agregado: line=$line, btoa=$btoa, index[line]=$index");
        }
      }
    }
    print("uniqueLcs: btoa: $btoa");

    // Este es el algoritmo de ordenamiento Patience
    // ver http://en.wikipedia.org/wiki/Patience_sorting
    final backpointers = List<int?>.filled(bct, null);
    final stacksAndLasts = <Pair>[];
    var k = 0;

    for (var bpos = 0; bpos < btoa.length; bpos++) {
      final apos = btoa[bpos];
      print("uniqueLcs: Ordenamiento Patience: bpos=$bpos, apos=$apos");
      if (apos == null) continue;

      // Como optimización, verificar si la siguiente línea viene al final,
      // porque generalmente lo hace
      if (stacksAndLasts.isNotEmpty && stacksAndLasts.last.a < apos) {
        k = stacksAndLasts.length;
        print("uniqueLcs: Ordenamiento Patience: Optimización 1: k=$k");
      }
      // Como optimización, verificar si la siguiente línea viene justo después
      // de la línea anterior, porque generalmente lo hace
      else if (stacksAndLasts.isNotEmpty &&
          stacksAndLasts[k].a < apos &&
          (k == stacksAndLasts.length - 1 || stacksAndLasts[k + 1].a > apos)) {
        k++;
        print("uniqueLcs: Ordenamiento Patience: Optimización 2: k=$k");
      }
      // Encontrar la ubicación de la pila
      else {
        print("uniqueLcs: Ordenamiento Patience: Llamando a binarySearch");
        k = binarySearch(stacksAndLasts, apos);
        print("uniqueLcs: Ordenamiento Patience: binarySearch devuelto: k=$k");
      }

      if (k > 0) {
        backpointers[bpos] = stacksAndLasts[k - 1].b;
        print("uniqueLcs: Ordenamiento Patience: backpointers[$bpos]=${stacksAndLasts[k - 1].b}");
      }

      if (k < stacksAndLasts.length) {
        stacksAndLasts[k] = Pair(apos, bpos);
        print("uniqueLcs: Ordenamiento Patience: stacksAndLasts[$k]=Pair($apos, $bpos)");
      } else {
        stacksAndLasts.add(Pair(apos, bpos));
        print("uniqueLcs: Ordenamiento Patience: stacksAndLasts.add(Pair($apos, $bpos))");
      }
      print("uniqueLcs: Ordenamiento Patience: stacksAndLasts=$stacksAndLasts");
    }
    print("uniqueLcs: backpointers: $backpointers");
    print("uniqueLcs: stacksAndLasts: $stacksAndLasts");

    if (stacksAndLasts.isEmpty) return [];

    int? j = stacksAndLasts.last.b;
    print("uniqueLcs: j=$j");

    // Reutilizando la lista StacksAndLasts para los resultados - tiene la longitud y el tipo correctos.
    k = stacksAndLasts.length;
    print("uniqueLcs: k=$k");

    while (j != null) {
      print("uniqueLcs: Bucle final: j=$j, k=$k");
      stacksAndLasts[--k] = Pair(btoa[j]!, j!);
      j = backpointers[j];
    }
    print("uniqueLcs: stacksAndLasts.sublist(k): ${stacksAndLasts.sublist(k)}");
    return stacksAndLasts.sublist(k);
  }

  /// Realiza una búsqueda binaria para el primer [Pair.a] que sea mayor
  /// que el valor especificado.
  ///
  /// [pairs]: La lista de pares para buscar.
  /// [search]: El valor para buscar.
  ///
  /// Devuelve el índice del valor o [0] si no se encontró.
  int binarySearch(List<Pair> pairs, int search) {
    var left = -1;
    var right = pairs.length;

    while (left + 1 < right) {
      var middle = (left + right) ~/ 2;
      if (pairs[middle].a > search) {
        right = middle;
      } else {
        left = middle;
      }
    }

    return left == -1 ? 0 : left;
  }

  /// Aplica recursivamente [PatienceSequenceMatcher] a dos listas.
  ///
  /// [a]: La primera lista.
  /// [b]: La segunda lista.
  /// [aLow]: El índice inicial en [a] (inclusivo).
  /// [bLow]: El índice inicial en [b] (inclusivo).
  /// [aHigh]: El índice final en [a] (exclusivo).
  /// [bHigh]: El índice final en [b] (exclusivo).
  /// [maxRecursion]: El número máximo de pasos recursivos a tomar.
  ///
  /// Devuelve las subsecuencias resultantes.
  Iterable<Pair> recurseMatches(List<T> a, List<T> b, int aLow, int bLow, int aHigh, int bHigh, int maxRecursion) sync* {
    if (maxRecursion < 0 || aLow >= aHigh || bLow >= bHigh) return;

    var added = false;
    var lastAPos = aLow - 1;
    var lastBPos = bLow - 1;

    for (var pair in uniqueLcs(a, b, aLow, bLow, aHigh, bHigh)) {
      // recursar entre líneas que son únicas en cada archivo y coinciden
      var apos = pair.a + aLow;
      var bpos = pair.b + bLow;

      // La mayoría de las veces, tendrá una secuencia de entradas similares
      if (lastAPos + 1 != apos || lastBPos + 1 != bpos) {
        for (var item in recurseMatches(a, b, lastAPos + 1, lastBPos + 1, apos, bpos, maxRecursion - 1)) {
          added = true;
          yield item;
        }
      }

      lastAPos = apos;
      lastBPos = bpos;
      added = true;
      yield pair;
    }

    // encontrar coincidencias entre la última coincidencia y el final
    if (added) {
      for (var item in recurseMatches(a, b, lastAPos + 1, lastBPos + 1, aHigh, bHigh, maxRecursion - 1)) {
        yield item;
      }
    }
    // encontrar líneas coincidentes al principio
    else if (_equality.equals(a[aLow], b[bLow])) {
      while (aLow < aHigh && bLow < bHigh && _equality.equals(a[aLow], b[bLow])) {
        yield Pair(aLow++, bLow++);
      }
      for (var item in recurseMatches(a, b, aLow, bLow, aHigh, bHigh, maxRecursion - 1)) {
        yield item;
      }
    }
    // encontrar líneas coincidentes al final
    else if (_equality.equals(a[aHigh - 1], b[bHigh - 1])) {
      var nahi = aHigh - 1;
      var nbhi = bHigh - 1;

      while (nahi > aLow && nbhi > bLow && _equality.equals(a[nahi - 1], b[nbhi - 1])) {
        nahi--;
        nbhi--;
      }

      for (var item in recurseMatches(a, b, lastAPos + 1, lastBPos + 1, nahi, nbhi, maxRecursion - 1)) {
        yield item;
      }
      for (var i = 0; i < aHigh - nahi; i++) {
        yield Pair(nahi + i, nbhi + i);
      }
    }
  }

  /// Encuentra regiones en listas de [Pair] donde ambos
  /// se incrementan al mismo tiempo.
  ///
  /// [list]: La lista para encontrar secuencias dentro.
  ///
  /// Devuelve las secuencias coincidentes.
  Iterable<SubSequence> collapseSequences(Iterable<Pair> list) sync* {
    var starta = null;
    var startb = null;
    var length = 0;

    for (var pair in list) {
      var a = pair.a;
      var b = pair.b;

      if (starta != null && a == starta + length && b == startb + length) {
        length += 1;
      } else {
        if (starta != null) {
          yield SubSequence(starta, startb, length);
        }
        starta = a;
        startb = b;
        length = 1;
      }
    }

    if (length != 0) {
      yield SubSequence(starta!, startb!, length);
    }
  }

  /// Encuentra bloques dentro de dos secuencias que coinciden.
  ///
  /// [left]: La secuencia de la izquierda.
  /// [right]: La secuencia de la derecha.
  ///
  /// Devuelve una lista de secuencias que representan los bloques que son iguales en ambas
  /// las secuencias de la izquierda y la derecha, ordenadas por su aparición en ambas.
  Iterable<SubSequence> findMatchingBlocks(List<T> left, List<T> right) {
    if (left == null) throw ArgumentError.notNull('left');
    if (right == null) throw ArgumentError.notNull('right');

    var matches = recurseMatches(left, right, 0, 0, left.length, right.length, 10);
    return collapseSequences(matches);
  }
}

/// Representa un par de enteros, donde ambos pueden ser nulos.
class NullablePair {
  final int? a;
  final int? b;

  NullablePair(this.a, this.b);

  NullablePair setA(int? a) => NullablePair(a, b);
  NullablePair setB(int? b) => NullablePair(a, b);
}

/// Representa un par de enteros.
class Pair {
  final int a;
  final int b;

  Pair(this.a, this.b);

  Pair setA(int a) => Pair(a, b);
  Pair setB(int b) => Pair(a, b);
}

/// Representa una subsecuencia dentro de una secuencia.
class SubSequence {
  final int startA;
  final int startB;
  final int length;

  SubSequence(this.startA, this.startB, this.length);
}

/// Define cómo comparar dos objetos de tipo [T] para determinar si son iguales.
abstract class EqualityComparer<T> {
  /// Determina si dos objetos de tipo [T] son iguales.
  bool equals(T x, T y);

  /// Devuelve un código hash para el objeto especificado.
  int getHashCode(T obj);

  /// Devuelve un comparador de igualdad predeterminado para el tipo [T].
  factory EqualityComparer() => _DefaultEqualityComparer<T>();
}

/// Implementación predeterminada de [EqualityComparer] que utiliza `==` y `hashCode`.
class _DefaultEqualityComparer<T> implements EqualityComparer<T> {
  @override
  bool equals(T x, T y) => x == y;

  @override
  int getHashCode(T obj) => obj.hashCode;
}

/// Comparador de igualdad para cadenas que ignora mayúsculas y minúsculas.
class CaseInsensitiveEqualityComparer implements EqualityComparer<String> {
  @override
  bool equals(String x, String y) => x.toLowerCase() == y.toLowerCase();

  @override
  int getHashCode(String obj) => obj.toLowerCase().hashCode;
}
