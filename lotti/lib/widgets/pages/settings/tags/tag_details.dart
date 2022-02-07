import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/persistence_logic.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/pages/settings/form_text_field.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TagDetailRoute extends StatefulWidget {
  const TagDetailRoute({
    Key? key,
    required this.tagEntity,
  }) : super(key: key);

  final TagEntity tagEntity;

  @override
  _TagDetailRouteState createState() {
    return _TagDetailRouteState();
  }
}

class _TagDetailRouteState extends State<TagDetailRoute> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: AppBar(
        foregroundColor: AppColors.appBarFgColor,
        title: Text(
          widget.tagEntity.tag,
          style: TextStyle(
            color: AppColors.entryTextColor,
            fontFamily: 'Oswald',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              _formKey.currentState!.save();
              if (_formKey.currentState!.validate()) {
                final formData = _formKey.currentState?.value;
                TagEntity tagEntity = widget.tagEntity.copyWith(
                  tag: '${formData!['tag']}'.trim(),
                  private: formData['private'],
                  inactive: formData['inactive'],
                  updatedAt: DateTime.now(),
                );
                persistenceLogic.upsertTagEntity(tagEntity);
                Navigator.pop(context);
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Save',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'Oswald',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        backgroundColor: AppColors.headerBgColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: AppColors.headerBgColor,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: <Widget>[
                          FormTextField(
                            initialValue: widget.tagEntity.tag,
                            labelText: 'Tag',
                            name: 'tag',
                          ),
                          FormBuilderSwitch(
                            name: 'private',
                            initialValue: widget.tagEntity.private,
                            title: Text(
                              'Private: ',
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.private,
                          ),
                          FormBuilderSwitch(
                            name: 'inactive',
                            initialValue: widget.tagEntity.inactive,
                            title: Text(
                              'Hide from suggestions: ',
                              style: formLabelStyle,
                            ),
                            activeColor: AppColors.private,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(MdiIcons.trashCanOutline),
                            iconSize: 24,
                            tooltip: 'Delete',
                            color: AppColors.appBarFgColor,
                            onPressed: () {
                              persistenceLogic.upsertTagEntity(
                                widget.tagEntity.copyWith(
                                  deletedAt: DateTime.now(),
                                ),
                              );
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
