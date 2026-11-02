class Station {
  final int id;
  final String nameEn;
  final String nameMr;
  final bool isDepot;

  const Station({
    required this.id,
    required this.nameEn,
    required this.nameMr,
    this.isDepot = false,
  });

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      id: (map['id'] as int?) ?? 0,
      nameEn: (map['name_en'] as String?) ?? '',
      nameMr: (map['name_mr'] as String?) ?? '',
      isDepot: (map['is_depot'] as int?) == 1,
    );
  }

  String displayName(bool isMarathi) {
    if (isMarathi && nameMr.isNotEmpty) {
      return nameMr;
    }
    return nameEn;
  }

  String secondaryName(bool isMarathi) {
    if (isMarathi) {
      return nameEn;
    }
    return nameMr.isNotEmpty ? nameMr : nameEn;
  }
}
