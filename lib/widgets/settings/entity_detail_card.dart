import 'package:flutter/material.dart';

class EntityDetailCard extends StatelessWidget {
  const EntityDetailCard({
    required this.child,
    this.contentPadding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Card(
          child: Padding(
            padding: contentPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}
