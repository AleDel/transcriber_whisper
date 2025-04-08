// Clase para calcular las diferencias entre dos listas de strings usando el algoritmo de Myers
class Diff {
  final List<String> a; // Primera lista de strings (texto de referencia)
  final List<String> b; // Segunda lista de strings (transcripción)
  final List<DiffChange> changes = []; // Lista de cambios (inserciones y eliminaciones)

  Diff(this.a, this.b) {
    _calculateDiff(); // Calcula las diferencias al crear el objeto
  }

  // Calcula las diferencias usando el algoritmo de Myers
  void _calculateDiff() {
    final int n = a.length;
    final int m = b.length;

    // Casos base: listas vacías
    if (n == 0 && m == 0) {
      return;
    }

    if (n == 0) {
      for (int i = 0; i < m; i++) {
        changes.add(DiffChange(DiffChangeType.insert, -1, i));
      }
      return;
    }

    if (m == 0) {
      for (int i = 0; i < n; i++) {
        changes.add(DiffChange(DiffChangeType.delete, i, -1));
      }
      return;
    }

    final int max = n + m;
    final List<int> v = List.filled(2 * max + 1, 0);

    // Función para encontrar las coincidencias (snakes)
    int snake(int k, int p, int q) {
      // Corrección: Asegurarse de que el índice k + max nunca sea negativo
      if (k + max < 0) {
        print("snake - k + max es negativo: k = $k, max = $max");
        return 0; // O manejar el caso de otra manera si es necesario
      }
      print("snake - k: $k, p: $p, q: $q, max: $max");
      int y = v[k + max];
      int x = y - k;
      print("snake - x: $x, y: $y");
      while (p < n && q < m && a[p] == b[q]) {
        p++;
        q++;
        x++;
        y++;
        print("snake - Coincidencia encontrada, x: $x, y: $y, p: $p, q: $q");
      }
      v[k + max] = y;
      print("snake - v[k + max] = $y");
      return x;
    }

    // Bucle principal del algoritmo de Myers
    for (int d = 0; d <= max; d++) {
      for (int k = -d; k <= d; k += 2) {
        print("_calculateDiff - d: $d, k: $k");
        int p = (k == -d || (k != d && v[k - 1 + max] < v[k + 1 + max]))
            ? v[k + 1 + max]
            : v[k - 1 + max] + 1;
        int q = p - k;
        int x = snake(k, p, q);
        if (x >= n && v[k + max] >= m) {
          _traceBack(d, k);
          return;
        }
      }
    }
  }

  // Reconstruye las diferencias a partir de la matriz v
  void _traceBack(int d, int k) {
    print("_traceBack - d: $d, k: $k");
    final int max = a.length + b.length;
    final List<int> v = List.filled(2 * max + 1, 0);
    final List<DiffChange> tempChanges = [];
    int x = a.length;
    int y = b.length;
    for (; d > 0; d--) {
      print("_traceBack - Bucle d: $d, k: $k, x: $x, y: $y");
      int p = (k == -d || (k != d && v[k - 1 + max] < v[k + 1 + max]))
          ? v[k + 1 + max]
          : v[k - 1 + max] + 1;
      int q = p - k;
      print("_traceBack - p: $p, q: $q");
      int prevX = p;
      int prevY = q;
      while (x > prevX && y > prevY && a[x - 1] == b[y - 1]) {
        x--;
        y--;
        print("_traceBack - Coincidencia encontrada, x: $x, y: $y");
      }
      if (p == v[k + 1 + max]) {
        k++;
        tempChanges.add(DiffChange(DiffChangeType.insert, -1, y - 1));
        print("_traceBack - Inserción detectada, k: $k, y: ${y - 1}");
      } else {
        k--;
        tempChanges.add(DiffChange(DiffChangeType.delete, x - 1, -1));
        print("_traceBack - Eliminación detectada, k: $k, x: ${x - 1}");
      }
      x = prevX;
      y = prevY;
    }
    while (x > 0 && y > 0 && a[x - 1] == b[y - 1]) {
      x--;
      y--;
      print("_traceBack - Coincidencia final encontrada, x: $x, y: $y");
    }
    for (int i = tempChanges.length - 1; i >= 0; i--) {
      changes.add(tempChanges[i]);
      print("_traceBack - Cambio añadido: ${tempChanges[i]}");
    }
  }
}

// Enumeración para los tipos de cambio (inserción o eliminación)
enum DiffChangeType {
  insert,
  delete,
}

// Clase para representar un cambio (inserción o eliminación)
class DiffChange {
  final DiffChangeType type;
  final int indexA; // Índice en la lista a
  final int indexB; // Índice en la lista b

  DiffChange(this.type, this.indexA, this.indexB);

  @override
  String toString() {
    return 'DiffChange{type: $type, indexA: $indexA, indexB: $indexB}';
  }
}