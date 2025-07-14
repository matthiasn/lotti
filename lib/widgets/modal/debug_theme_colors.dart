import 'package:flutter/material.dart';

class DebugThemeColors extends StatelessWidget {
  const DebugThemeColors({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ColorRow('surface', colorScheme.surface),
        _ColorRow('surfaceContainer', colorScheme.surfaceContainer),
        _ColorRow('surfaceContainerLow', colorScheme.surfaceContainerLow),
        _ColorRow('surfaceContainerHigh', colorScheme.surfaceContainerHigh),
        _ColorRow('surfaceContainerHighest', colorScheme.surfaceContainerHighest),
        _ColorRow('primary', colorScheme.primary),
        _ColorRow('primaryContainer', colorScheme.primaryContainer),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow(this.name, this.color);
  
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}