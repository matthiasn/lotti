import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/journal/journal_image_cubit.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/app_bar_version.dart';
import 'package:lotti/widgets/pages/add/editor_page.dart';
import 'package:lotti/widgets/pages/add/health_page.dart';
import 'package:lotti/widgets/pages/add/new_measurement_page.dart';
import 'package:lotti/widgets/pages/add/survey_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class AddPage extends StatefulWidget {
  const AddPage({
    Key? key,
    this.navigatorKey,
  }) : super(key: key);

  final GlobalKey? navigatorKey;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext _context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
        builder: (context, PersistenceState state) {
      return Scaffold(
        appBar: const VersionAppBar(title: 'Add Entry'),
        backgroundColor: AppColors.bodyBgColor,
        body: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const <Widget>[],
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                child: const Icon(
                  MdiIcons.tapeMeasure,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return const NewMeasurementPage();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(
                width: 16,
              ),
              FloatingActionButton(
                child: const Icon(
                  MdiIcons.clipboardOutline,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return const SurveyPage();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(
                width: 16,
              ),
              FloatingActionButton(
                child: const Icon(
                  Icons.camera_roll,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  context.read<JournalImageCubit>().pickImageAssets(context);
                },
              ),
              const SizedBox(
                width: 16,
              ),
              FloatingActionButton(
                child: const Icon(
                  MdiIcons.textLong,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return const EditorPage();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(
                width: 16,
              ),
              FloatingActionButton(
                child: const Icon(
                  MdiIcons.heart,
                  size: 32,
                ),
                backgroundColor: AppColors.entryBgColor,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (BuildContext context) {
                        return const HealthPage();
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
