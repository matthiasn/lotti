import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/profile_selector.dart';
import 'package:lotti/features/agents/ui/template_selector.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/state/category_details_controller.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_correction_examples.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_display.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';
import 'package:lotti/features/categories/ui/widgets/category_language_dropdown.dart';
import 'package:lotti/features/categories/ui/widgets/category_name_field.dart';
import 'package:lotti/features/categories/ui/widgets/category_speech_dictionary.dart';
import 'package:lotti/features/categories/ui/widgets/category_switch_tiles.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/projects/ui/widgets/category_projects_section.dart';
import 'package:lotti/features/tasks/ui/widgets/language_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

part 'category_details_page_state.dart';

part 'category_details_form_sections.dart';

/// Category Details Page with AI Settings and Projects
///
/// This page allows editing of category details including:
/// - Basic settings (name, color, privacy, active status)
/// - Default language selection
/// - Allowed AI models/prompts
/// - Automatic prompt configuration
/// - Projects within this category
class CategoryDetailsPage extends ConsumerStatefulWidget {
  const CategoryDetailsPage({
    this.categoryId,
    super.key,
  });

  final String? categoryId;

  bool get isCreateMode => categoryId == null;

  @override
  ConsumerState<CategoryDetailsPage> createState() =>
      _CategoryDetailsPageState();
}
