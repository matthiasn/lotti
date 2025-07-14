import 'package:flutter/material.dart';

class DebugColorWidget extends StatelessWidget {
  const DebugColorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Brightness: ${brightness.name}'),
          const SizedBox(height: 8),
          _ColorInfo('surfaceContainerHigh', colorScheme.surfaceContainerHigh),
          _ColorInfo('surfaceContainerHighest', colorScheme.surfaceContainerHighest),
          const SizedBox(height: 8),
          // Test containers
          Container(
            height: 50,
            color: colorScheme.surfaceContainerHigh,
            alignment: Alignment.center,
            child: const Text('surfaceContainerHigh'),
          ),
          const SizedBox(height: 4),
          Container(
            height: 50,
            color: colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Text('surfaceContainerHighest'),
          ),
        ],
      ),
    );
  }
}

class _ColorInfo extends StatelessWidget {
  const _ColorInfo(this.name, this.color);
  
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          color: color,
          margin: const EdgeInsets.only(right: 8),
        ),
        Text('$name: #${color.value.toRadixString(16).toUpperCase()}'),
      ],
    );
  }
}