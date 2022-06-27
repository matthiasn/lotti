import 'package:auto_route/auto_route.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class CreateMeasurementPage extends StatefulWidget {
  const CreateMeasurementPage({
    super.key,
    this.linkedId,
    this.selectedId,
  });

  final String? linkedId;
  final String? selectedId;

  @override
  State<CreateMeasurementPage> createState() => _CreateMeasurementPageState();
}

class _CreateMeasurementPageState extends State<CreateMeasurementPage> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  MeasurableDataType? selected;

  final hotkeyCmdS = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  @override
  void initState() {
    super.initState();

    hotKeyManager.register(
      hotkeyCmdS,
      keyDownHandler: (hotKey) => saveMeasurement(),
    );
  }

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregister(hotkeyCmdS);
  }

  bool validate() {
    if (_formKey.currentState != null) {
      return _formKey.currentState!.validate();
    }
    return false;
  }

  Future<void> saveMeasurement() async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;
      if (selected == null) {
        return;
      }
      final measurement = MeasurementData(
        dataTypeId: selected!.id,
        dateTo: formData!['date'] as DateTime,
        dateFrom: formData['date'] as DateTime,
        value: nf.parse('${formData['value']}'.replaceAll(',', '.')),
      );
      await persistenceLogic.createMeasurementEntry(
        data: measurement,
        linkedId: widget.linkedId,
      );
      setState(() {
        dirty = false;
      });

      await getIt<AppRouter>().pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<MeasurableDataType>>(
      stream: _db.watchMeasurableDataTypes(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        if (items.length == 1) {
          selected = items.first;
        }

        for (final dataType in items) {
          if (dataType.id == widget.selectedId) {
            selected = dataType;
          }
        }

        return Scaffold(
          appBar: TitleAppBar(
            title: localizations.addMeasurementTitle,
            actions: [
              if (dirty && validate())
                TextButton(
                  key: const Key('measurement_save'),
                  onPressed: saveMeasurement,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      localizations.addMeasurementSaveButton,
                      style: saveButtonStyle,
                    ),
                  ),
                ),
            ],
          ),
          backgroundColor: AppColors.bodyBgColor,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: AppColors.headerBgColor,
                    width: MediaQuery.of(context).size.width,
                    padding: const EdgeInsets.all(32),
                    child: FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: () {
                        setState(() {
                          dirty = true;
                        });
                      },
                      child: Column(
                        children: <Widget>[
                          if (items.isEmpty)
                            Row(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      pushNamedRoute(
                                        '/settings/create_measurable',
                                      );
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width -
                                          100,
                                      child: AutoSizeText(
                                        localizations.addMeasurementNoneDefined,
                                        style: titleStyle.copyWith(
                                          decoration: TextDecoration.underline,
                                          color: AppColors.tagColor,
                                        ),
                                        wrapWords: false,
                                        maxLines: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (items.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        selected?.displayName ?? '',
                                        style: TextStyle(
                                          color: AppColors.entryTextColor,
                                          fontFamily: 'Oswald',
                                          fontSize: 24,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings_outlined),
                                      color: AppColors.entryTextColor,
                                      onPressed: () {
                                        getIt<AppRouter>().pushNamed(
                                          '/settings/measurables/${selected?.id}',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                if (selected?.description != null)
                                  Text(
                                    selected!.description,
                                    style: TextStyle(
                                      color: AppColors.entryTextColor,
                                      fontFamily: 'Oswald',
                                      fontWeight: FontWeight.w300,
                                      fontSize: 14,
                                    ),
                                  ),
                                if (selected == null)
                                  FormBuilderDropdown<MeasurableDataType>(
                                    dropdownColor: AppColors.headerBgColor,
                                    name: 'type',
                                    decoration: InputDecoration(
                                      labelText: 'Type',
                                      labelStyle: labelStyle,
                                    ),
                                    hint: Text(
                                      'Select Measurement Type',
                                      style: inputStyle,
                                    ),
                                    onChanged: (MeasurableDataType? value) {
                                      setState(() {
                                        selected = value;
                                      });
                                    },
                                    validator: FormBuilderValidators.compose(
                                      [FormBuilderValidators.required()],
                                    ),
                                    items: items
                                        .map(
                                          (MeasurableDataType item) =>
                                              DropdownMenuItem(
                                            value: item,
                                            child: Text(
                                              item.displayName,
                                              style: inputStyle,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                if (selected != null)
                                  FormBuilderCupertinoDateTimePicker(
                                    name: 'date',
                                    alwaysUse24HourFormat: true,
                                    format: DateFormat(
                                      "EEEE, MMMM d, yyyy 'at' HH:mm",
                                    ),
                                    style: inputStyle,
                                    decoration: InputDecoration(
                                      labelText: 'Measurement taken',
                                      labelStyle: labelStyle,
                                    ),
                                    initialValue: DateTime.now(),
                                    theme: DatePickerTheme(
                                      headerColor: AppColors.headerBgColor,
                                      backgroundColor: AppColors.bodyBgColor,
                                      itemStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                      doneStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                if (selected != null)
                                  FormBuilderTextField(
                                    initialValue: '',
                                    key: const Key('measurement_value_field'),
                                    decoration: InputDecoration(
                                      labelText: '${selected?.displayName} '
                                          '${'${selected?.unitName}'.isNotEmpty ? '[${selected?.unitName}] ' : ''}',
                                      labelStyle: labelStyle,
                                    ),
                                    keyboardAppearance: Brightness.dark,
                                    style: inputStyle,
                                    autofocus: true,
                                    validator: FormBuilderValidators.required(),
                                    name: 'value',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selected != null)
                  DashboardMeasurablesChart(
                    measurableDataTypeId: selected!.id,
                    rangeStart: getRangeStart(context: context),
                    rangeEnd: getRangeEnd(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CreateMeasurementWithLinkedPage extends StatelessWidget {
  const CreateMeasurementWithLinkedPage({
    super.key,
    @PathParam() this.linkedId,
  });

  final String? linkedId;

  @override
  Widget build(BuildContext context) {
    return CreateMeasurementPage(
      linkedId: linkedId,
    );
  }
}

class CreateMeasurementWithTypePage extends StatelessWidget {
  const CreateMeasurementWithTypePage({
    super.key,
    @PathParam() this.selectedId,
  });

  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    return CreateMeasurementPage(
      selectedId: selectedId,
    );
  }
}
