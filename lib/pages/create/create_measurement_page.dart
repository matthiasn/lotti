import 'package:auto_size_text/auto_size_text.dart';
import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/form_utils.dart';
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

    // TODO: bring back
    // hotKeyManager.register(
    //   hotkeyCmdS,
    //   keyDownHandler: (hotKey) => saveMeasurement(),
    // );
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void beamBack() => context.beamBack();

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
          private: false,
        );

        setState(() {
          dirty = false;
        });

//        maybePop();
        beamBack();
      }
    }

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
                      style: saveButtonStyle(),
                    ),
                  ),
                ),
            ],
          ),
          backgroundColor: styleConfig().negspace,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: Container(
                    color: styleConfig().cardColor,
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
                          if (snapshot.hasData && items.isEmpty)
                            Row(
                              children: [
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      beamToNamed(
                                        '/settings/create_measurable',
                                      );
                                    },
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width -
                                          100,
                                      child: AutoSizeText(
                                        localizations.addMeasurementNoneDefined,
                                        style: titleStyle().copyWith(
                                          decoration: TextDecoration.underline,
                                          color: styleConfig().primaryTextColor,
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
                                          color: styleConfig().primaryTextColor,
                                          fontFamily: 'Oswald',
                                          fontSize: fontSizeLarge,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings_outlined),
                                      color: styleConfig().primaryTextColor,
                                      onPressed: () {
                                        beamToNamed(
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
                                      color: styleConfig().primaryTextColor,
                                      fontFamily: 'Oswald',
                                      fontWeight: FontWeight.w300,
                                      fontSize: fontSizeMedium,
                                    ),
                                  ),
                                if (selected == null)
                                  FormBuilderDropdown<MeasurableDataType>(
                                    dropdownColor: styleConfig().cardColor,
                                    name: 'type',
                                    decoration: InputDecoration(
                                      labelText: 'Type',
                                      labelStyle: labelStyle(),
                                      hintStyle: inputStyle(),
                                      hintText: 'Select Measurement Type',
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
                                              style: inputStyle(),
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
                                    style: inputStyle(),
                                    decoration: InputDecoration(
                                      labelText: 'Measurement taken',
                                      labelStyle: labelStyle(),
                                    ),
                                    initialValue: DateTime.now(),
                                    theme: datePickerTheme(),
                                  ),
                                if (selected != null)
                                  FormBuilderTextField(
                                    initialValue: '',
                                    key: const Key('measurement_value_field'),
                                    decoration: InputDecoration(
                                      labelText: '${selected?.displayName} '
                                          '${'${selected?.unitName}'.isNotEmpty ? '[${selected?.unitName}] ' : ''}',
                                      labelStyle: labelStyle(),
                                    ),
                                    keyboardAppearance: Brightness.dark,
                                    style: inputStyle(),
                                    autofocus: true,
                                    validator: numericValidator(),
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
                    dashboardId: null,
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
