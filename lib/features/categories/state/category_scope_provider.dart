import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which categories the app may show right now, by id, or null when all of
/// them. The composition root wires the lockdown feature's scope here, so
/// every category list stays inside an active lockdown without categories
/// depending on lockdown.
final categoryScopeProvider = Provider<bool Function(String categoryId)?>(
  (ref) => null,
  name: 'categoryScopeProvider',
);
