import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_rating/flutter_rating.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/categories/category_field.dart';
import 'package:lotti/widgets/events/event_status.dart';

class EventForm extends ConsumerStatefulWidget {
  const EventForm(
    this.event, {
    super.key,
    this.focusOnTitle = false,
  });

  final JournalEvent event;
  final bool focusOnTitle;

  @override
  ConsumerState<EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<EventForm> {
  double stars = 0;

  @override
  void initState() {
    super.initState();
    stars = widget.event.data.stars;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.event.data;

    final entryId = widget.event.meta.id;
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final save = notifier.save;
    final formKey = entryState?.formKey;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const SizedBox(height: 10),
                FormBuilderTextField(
                  autofocus: widget.focusOnTitle,
                  focusNode: notifier.eventTitleFocusNode,
                  initialValue: data.title,
                  decoration: inputDecoration(
                    labelText: data.title.isEmpty
                        ? context.messages.eventNameLabel
                        : '',
                    themeData: Theme.of(context),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  keyboardAppearance: Theme.of(context).brightness,
                  maxLines: null,
                  style: const TextStyle(fontSize: fontSizeLarge),
                  name: 'title',
                  onChanged: (_) => notifier.setDirty(value: true),
                ),
                inputSpacer,
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: CategoryField(
                        categoryId: widget.event.meta.categoryId,
                        onSave: (category) {
                          notifier.updateCategoryId(category?.id);
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: FormBuilderDropdown<EventStatus>(
                        name: 'status',
                        borderRadius: BorderRadius.circular(10),
                        elevation: 2,
                        onChanged: (dynamic _) => save(),
                        decoration: inputDecoration(
                          labelText: 'Status:',
                          themeData: Theme.of(context),
                        ),
                        initialValue: data.status,
                        items: [
                          dropDownMenuItem(EventStatus.tentative),
                          dropDownMenuItem(EventStatus.planned),
                          dropDownMenuItem(EventStatus.ongoing),
                          dropDownMenuItem(EventStatus.completed),
                          dropDownMenuItem(EventStatus.cancelled),
                          dropDownMenuItem(EventStatus.postponed),
                          dropDownMenuItem(EventStatus.rescheduled),
                          dropDownMenuItem(EventStatus.missed),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: StarRating(
                        rating: stars,
                        allowHalfRating: true,
                        size: 32,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        onRatingChanged: (rating) {
                          setState(() {
                            stars = rating;
                          });
                          notifier.updateRating(rating);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        EditorWidget(entryId: entryId),
      ],
    );
  }
}

DropdownMenuItem<EventStatus> dropDownMenuItem(EventStatus status) {
  return DropdownMenuItem<EventStatus>(
    value: status,
    child: EventStatusWidget(status),
  );
}
