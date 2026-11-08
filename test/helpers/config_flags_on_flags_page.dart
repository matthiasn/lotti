import 'package:lotti/classes/config_flag_placement.dart';

/// Every flag the Config Flags page renders, flattened across the groups in
/// render order — the view the coverage and retirement checks read.
List<String> get configFlagsOnFlagsPage => [
  for (final group in ConfigFlagGroup.values) ...?configFlagGroups[group],
];
