import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/generated/design_tokens.g.dart';

export 'generated/design_tokens.g.dart';

extension DesignTokensBuildContextExtension on BuildContext {
  DsTokens get designTokens {
    final tokens = Theme.of(this).extension<DsTokens>();
    assert(
      tokens != null,
      'DsTokens extension is missing from the active theme.',
    );
    return tokens!;
  }
}
