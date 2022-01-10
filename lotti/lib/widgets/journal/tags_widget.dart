import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class TagsWidget extends StatelessWidget {
  const TagsWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          Chip(
            backgroundColor: AppColors.entryBgColor,
            label: Text('Photo'),
          ),
          Chip(
            backgroundColor: AppColors.entryBgColor,
            label: Text('Panama'),
          ),
          Chip(
            backgroundColor: AppColors.entryBgColor,
            label: Text('Panama Canal'),
            elevation: 1,
          ),
          Chip(
            label: Text('sunny'),
            backgroundColor: AppColors.entryBgColor,
          ),
          Chip(
            label: Text('tropical'),
            backgroundColor: AppColors.entryBgColor,
          ),
          Chip(
            backgroundColor: AppColors.entryBgColor,
            label: Text('Ship'),
          ),
          Chip(
            backgroundColor: AppColors.entryBgColor,
            label: Text('Container Ship'),
          ),
        ],
      ),
    );
  }
}
