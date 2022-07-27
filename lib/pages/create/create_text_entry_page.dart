import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';

class CreateTextEntryPage extends StatefulWidget {
  const CreateTextEntryPage({
    super.key,
    @PathParam() this.linkedId,
  });

  final String? linkedId;

  @override
  State<CreateTextEntryPage> createState() => _CreateTextEntryPageState();
}

class _CreateTextEntryPageState extends State<CreateTextEntryPage> {
  final QuillController _controller = makeController();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  DateTime started = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    Future<void> _save() async {
      await persistenceLogic.createTextEntry(
        entryTextFromController(_controller),
        linkedId: widget.linkedId,
        started: started,
      );
      await HapticFeedback.heavyImpact();

      // ignore: use_build_context_synchronously
      FocusScope.of(context).unfocus();
      await getIt<AppRouter>().pop();
    }

    return Scaffold(
      appBar: TitleAppBar(
        title: localizations.addEntryTitle,
      ),
      backgroundColor: colorConfig().bodyBgColor,
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: EditorWidget(
              minHeight: 200,
              autoFocus: true,
            ),
          ),
        ),
      ),
    );
  }
}
