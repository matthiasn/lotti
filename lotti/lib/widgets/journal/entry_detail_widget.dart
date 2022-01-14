import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/audio/audio_player.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_datetime_modal.dart';
import 'package:lotti/widgets/journal/entry_image_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/map_widget.dart';
import 'package:lotti/widgets/misc/survey_summary.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/src/provider.dart';

class EntryDetailWidget extends StatefulWidget {
  final JournalEntity item;
  final bool readOnly;
  const EntryDetailWidget({
    Key? key,
    required this.item,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<EntryDetailWidget> createState() => _EntryDetailWidgetState();
}

class _EntryDetailWidgetState extends State<EntryDetailWidget> {
  final FocusNode _focusNode = FocusNode();
  bool showDetails = false;

  Directory? docDir;
  bool mapVisible = false;
  double editorHeight = (Platform.isIOS || Platform.isAndroid) ? 280 : 400;
  double imageTextEditorHeight =
      (Platform.isIOS || Platform.isAndroid) ? 160 : 400;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        docDir = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Geolocation? loc = widget.item.geolocation;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  builder: (BuildContext context) {
                    return EntryDateTimeModal(
                      item: widget.item,
                    );
                  },
                );
              },
              child: Text(
                df.format(widget.item.meta.dateFrom),
                style: textStyle,
              ),
            ),
            Visibility(
              visible: loc != null && loc.longitude != 0,
              child: TextButton(
                onPressed: () => setState(() {
                  mapVisible = !mapVisible;
                }),
                child: Text(
                  '📍 ${formatLatLon(loc?.latitude)}, '
                  '${formatLatLon(loc?.longitude)}',
                  style: textStyle,
                ),
              ),
            ),
            IconButton(
              icon: Icon(showDetails
                  ? MdiIcons.chevronDoubleUp
                  : MdiIcons.chevronDoubleDown),
              iconSize: 24,
              tooltip: 'Details',
              color: AppColors.appBarFgColor,
              onPressed: () {
                setState(() {
                  showDetails = !showDetails;
                });
              },
            ),
          ],
        ),
        Visibility(
          visible: showDetails,
          child: EntryInfoRow(entityId: widget.item.meta.id),
        ),
        Visibility(
          visible: mapVisible,
          child: MapWidget(
            geolocation: widget.item.geolocation,
          ),
        ),
        widget.item.maybeMap(
          journalAudio: (JournalAudio audio) {
            QuillController _controller =
                makeController(serializedQuill: audio.entryText?.quill);

            void saveText() {
              EntryText entryText = entryTextFromController(_controller);

              context
                  .read<PersistenceCubit>()
                  .updateJournalEntityText(widget.item.meta.id, entryText);
            }

            return Column(
              children: [
                const AudioPlayerWidget(),
                EditorWidget(
                  controller: _controller,
                  focusNode: _focusNode,
                  height: editorHeight,
                  saveFn: saveText,
                ),
              ],
            );
          },
          journalImage: (JournalImage image) {
            QuillController _controller =
                makeController(serializedQuill: image.entryText?.quill);

            void saveText() {
              EntryText entryText = entryTextFromController(_controller);

              context
                  .read<PersistenceCubit>()
                  .updateJournalEntityText(widget.item.meta.id, entryText);
            }

            return Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black,
                  child: EntryImageWidget(
                    focusNode: _focusNode,
                    journalImage: image,
                    height: 200,
                  ),
                ),
                EditorWidget(
                  controller: _controller,
                  focusNode: _focusNode,
                  readOnly: widget.readOnly,
                  height: imageTextEditorHeight,
                  saveFn: saveText,
                ),
              ],
            );
          },
          journalEntry: (JournalEntry journalEntry) {
            QuillController _controller =
                makeController(serializedQuill: journalEntry.entryText.quill);

            void saveText() {
              context.read<PersistenceCubit>().updateJournalEntityText(
                  widget.item.meta.id, entryTextFromController(_controller));
            }

            return EditorWidget(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              saveFn: saveText,
            );
          },
          measurement: (MeasurementEntry entry) {
            QuillController _controller =
                makeController(serializedQuill: entry.entryText?.quill);

            void saveText() {
              context.read<PersistenceCubit>().updateJournalEntityText(
                  widget.item.meta.id, entryTextFromController(_controller));
            }

            return EditorWidget(
              controller: _controller,
              focusNode: _focusNode,
              readOnly: widget.readOnly,
              saveFn: saveText,
            );
          },
          survey: (SurveyEntry surveyEntry) => SurveySummaryWidget(surveyEntry),
          quantitative: (qe) => qe.data.map(
            cumulativeQuantityData: (qd) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: InfoText(
                'End: ${df.format(qe.meta.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
            ),
            discreteQuantityData: (qd) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: InfoText(
                'End: ${df.format(qe.meta.dateTo)}'
                '\n${formatType(qd.dataType)}: '
                '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
              ),
            ),
          ),
          orElse: () => Container(),
        ),
      ],
    );
  }
}

class EntryInfoRow extends StatelessWidget {
  final String entityId;
  final JournalDb db = getIt<JournalDb>();

  late final Stream<JournalEntity?> stream = db.watchEntityById(entityId);

  EntryInfoRow({
    Key? key,
    required this.entityId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<JournalEntity?> snapshot,
        ) {
          JournalEntity? liveEntity = snapshot.data;
          if (liveEntity == null) {
            return const SizedBox.shrink();
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SwitchRow(
                label: 'Starred:',
                onChanged: (bool value) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    starred: value,
                  );
                  context
                      .read<PersistenceCubit>()
                      .updateJournalEntity(liveEntity, newMeta);
                },
                value: liveEntity.meta.starred ?? false,
              ),
              SwitchRow(
                label: 'Private:',
                onChanged: (bool value) {
                  Metadata newMeta = liveEntity.meta.copyWith(
                    private: value,
                  );
                  context
                      .read<PersistenceCubit>()
                      .updateJournalEntity(liveEntity, newMeta);
                },
                value: liveEntity.meta.private ?? false,
              ),
              SwitchRow(
                label: 'Deleted:',
                onChanged: (bool value) {
                  if (value) {
                    context
                        .read<PersistenceCubit>()
                        .deleteJournalEntity(liveEntity);
                    Navigator.pop(context);
                  }
                },
                value: liveEntity.meta.deletedAt != null,
              ),
            ],
          );
        });
  }
}

class SwitchRow extends StatelessWidget {
  const SwitchRow({
    Key? key,
    required this.label,
    required this.onChanged,
    required this.value,
  }) : super(key: key);

  final String label;
  final void Function(bool)? onChanged;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: textStyle),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
