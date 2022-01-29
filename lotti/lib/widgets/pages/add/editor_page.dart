import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    Key? key,
    this.linked,
  }) : super(key: key);

  final JournalEntity? linked;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      void _save() async {
        context.read<PersistenceCubit>().createTextEntry(
              entryTextFromController(_controller),
              linked: widget.linked,
            );
        HapticFeedback.heavyImpact();

        _controller = makeController();
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      }

      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.headerBgColor,
          foregroundColor: AppColors.appBarFgColor,
        ),
        backgroundColor: AppColors.bodyBgColor,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8.0)),
                child: EditorWidget(
                  controller: _controller,
                  focusNode: _focusNode,
                  saveFn: _save,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
