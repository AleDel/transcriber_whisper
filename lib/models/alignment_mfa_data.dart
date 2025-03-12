class AlignmentMFAData {
  final double start;
  final double end;
  final Map<String, Tier> tiers;

  AlignmentMFAData({
    required this.start,
    required this.end,
    required this.tiers,
  });

  // Método para convertir el objeto AlignmentData a un mapa
  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'tiers': tiers.map((key, value) => MapEntry(key, value.toMap())), // Usamos el método toMap de Tier
    };
  }

  // Método para crear un objeto AlignmentData a partir de un mapa
  static AlignmentMFAData fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> tiersMap = Map<String, dynamic>.from(map['tiers']);
    final Map<String, Tier> tiers = {};
    tiersMap.forEach((key, value) {
      tiers[key] = Tier.fromMap(Map<String, dynamic>.from(value)); // Usamos el método fromMap de Tier
    });

    return AlignmentMFAData(
      start: map['start'].toDouble(),
      end: map['end'].toDouble(),
      tiers: tiers,
    );
  }
}

class Tier {
  final String type;
  final List<Entry> entries;

  Tier({
    required this.type,
    required this.entries,
  });

  // Método para convertir el objeto Tier a un mapa
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'entries': entries.map((entry) => entry.toMap()).toList(), // Usamos el método toMap de Entry
    };
  }

  // Método para crear un objeto Tier a partir de un mapa
  static Tier fromMap(Map<String, dynamic> map) {
    final List<dynamic> entriesList = List<dynamic>.from(map['entries']);
    final List<Entry> entries = entriesList.map((entry) => Entry.fromMap(List<dynamic>.from(entry))).toList(); // Usamos el método fromMap de Entry
    return Tier(
      type: map['type'],
      entries: entries,
    );
  }
}

class Entry {
  final double start;
  final double end;
  final String value;

  Entry({
    required this.start,
    required this.end,
    required this.value,
  });

  // Método para convertir el objeto Entry a un mapa
  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'value': value,
    };
  }

  // Método para crear un objeto Entry a partir de una lista
  static Entry fromMap(List<dynamic> list) {
    return Entry(
      start: list[0].toDouble(),
      end: list[1].toDouble(),
      value: list[2],
    );
  }
}