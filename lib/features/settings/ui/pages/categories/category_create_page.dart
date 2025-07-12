import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/settings/categories/category_settings_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/settings/ui/pages/categories/category_details_page.dart';
import 'package:lotti/utils/file_utils.dart';

class CreateCategoryPage extends StatelessWidget {
  CreateCategoryPage({super.key});

  final categoryDefinition = CategoryDefinition(
    id: uuid.v1(),
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    private: false,
    vectorClock: null,
    active: true,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CategorySettingsCubit>(
      create: (_) => CategorySettingsCubit(
        categoryDefinition,
        context: context,
      ),
      child: const CategoryDetailsPage(),
    );
  }
}
