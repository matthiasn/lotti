import 'package:flutter/material.dart';

class DiagnosticsPanel extends StatelessWidget {
  const DiagnosticsPanel({
    required this.fetchDiagnostics,
    super.key,
  });

  final Future<String> Function() fetchDiagnostics;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Diagnostics'),
      children: [
        FutureBuilder<String>(
          future: fetchDiagnostics(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              );
            }
            final txt = snap.data ?? '';
            final lines =
                txt.split('\n').where((l) => l.contains('=')).toList();
            final diag = <String, String>{};
            for (final l in lines) {
              final i = l.indexOf('=');
              if (i > 0) {
                diag[l.substring(0, i)] = l.substring(i + 1);
              }
            }
            final dbMissingBase = diag['dbMissingBase'] ?? '0';
            final ignoredCount =
                int.tryParse(diag['lastIgnoredCount'] ?? '0') ?? 0;
            final prefCount =
                int.tryParse(diag['lastPrefetchedCount'] ?? '0') ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('dbMissingBase: $dbMissingBase'),
                  const SizedBox(height: 6),
                  if (ignoredCount > 0) ...[
                    const Text('Last Ignored:'),
                    for (var i = 1; i <= ignoredCount; i++)
                      Text(diag['lastIgnored.$i'] ?? ''),
                    const SizedBox(height: 6),
                  ],
                  if (prefCount > 0) ...[
                    const Text('Last Prefetched:'),
                    for (var i = 1; i <= prefCount; i++)
                      Text(diag['lastPrefetched.$i'] ?? ''),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
