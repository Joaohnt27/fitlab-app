String canonicalSubscriptionName(String displayName) =>
    displayName.startsWith('Atleta ') ? displayName.substring(7) : displayName;

int subscriptionPlanId(List<dynamic> catalog, String displayName) {
  final name = canonicalSubscriptionName(displayName);
  final matches = catalog.where((p) => p is Map && p['nome'] == name).toList();
  if (matches.length != 1 || matches.single['id'] is! int) {
    throw const FormatException('Plano ausente ou ambíguo no catálogo.');
  }
  return matches.single['id'] as int;
}
