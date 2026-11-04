import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/agent_editor_scaffold.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// The person editor as a page — `/people/new` to add someone,
/// `/people/<id>/edit` to edit them — in the goal editor's container
/// ([AgentEditorScaffold]): the same app bar, canvas, reading column and
/// footer, so editing a person and editing a goal are the same kind of
/// screen.
///
/// Every way out goes through the form, which asks before dropping typed
/// work: the app bar's back, *Cancel* and the system back. A save lands on
/// the person's page.
class RelationshipEditorPage extends ConsumerStatefulWidget {
  const RelationshipEditorPage({this.relationshipId, super.key});

  /// The person to edit; null adds a new one.
  final String? relationshipId;

  @override
  ConsumerState<RelationshipEditorPage> createState() =>
      _RelationshipEditorPageState();
}

class _RelationshipEditorPageState
    extends ConsumerState<RelationshipEditorPage> {
  final _handle = RelationshipFormHandle();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  void _leave() {
    final id = widget.relationshipId;
    beamToNamed(id == null ? '/people' : '/people/$id');
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final id = widget.relationshipId;
    final editing = id != null;
    final title = editing
        ? messages.relationshipEditTitle
        : messages.relationshipCreateTitle;

    // The person as first read: the form keeps its own state from there, so
    // a reload under it (a photo it just wrote, a sync) never swaps it out.
    final RelationshipEntry? initial;
    if (editing) {
      final detailAsync = ref.watch(relationshipDetailControllerProvider(id));
      final person = detailAsync.value?.relationship;
      if (person == null) {
        // Until the first read lands, a spinner. After it, a person who
        // resolved to null is gone (deleted, here or on another device) and a
        // failed read says so, as the person page does, rather than spinning
        // forever. The error is checked first: while Riverpod retries a failed
        // read the state is loading *and* errored, and the retry's backoff
        // must not read as a load still on its way.
        final tokens = context.designTokens;
        final stillLoading = detailAsync.isLoading && !detailAsync.hasError;
        final body = stillLoading
            ? DesignSystemSpinner(semanticsLabel: messages.commonLoading)
            : Text(
                detailAsync.hasError
                    ? messages.commonError
                    : messages.relationshipNotFound,
                key: const ValueKey('person-editor-unavailable'),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              );
        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: _leave),
            title: Text(title),
          ),
          body: Center(child: body),
        );
      }
      initial = person;
    } else {
      initial = null;
    }

    return AgentEditorScaffold(
      title: title,
      onBack: _handle.dismiss,
      onCancel: _handle.dismiss,
      cancelKey: const ValueKey('person-form-cancel'),
      primary: ListenableBuilder(
        listenable: _handle,
        builder: (context, _) => DesignSystemButton(
          key: const ValueKey('person-form-save'),
          label: _handle.isEditing
              ? messages.saveButton
              : messages.createButton,
          onPressed: _handle.canSave ? _handle.save : null,
        ),
      ),
      body: [
        RelationshipForm(
          key: ValueKey('person-form-$id'),
          initial: initial,
          handle: _handle,
          onSaved: (saved) => beamToNamed('/people/${saved.id}'),
          onDismissed: _leave,
        ),
      ],
    );
  }
}
