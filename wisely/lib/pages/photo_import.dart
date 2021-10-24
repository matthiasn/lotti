import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/journal/journal_cubit.dart';
import 'package:wisely/blocs/journal/journal_state.dart';
import 'package:wisely/widgets/buttons.dart';

class PhotoImportPage extends StatefulWidget {
  const PhotoImportPage({Key? key}) : super(key: key);

  @override
  State<PhotoImportPage> createState() => _PhotoImportPageState();
}

class _PhotoImportPageState extends State<PhotoImportPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalCubit, JournalState>(
        builder: (BuildContext context, JournalState state) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Button(
                onPressed: () async {
                  context.read<JournalCubit>().pickImageAssets(context);
                },
                label: 'Pick Assets',
                primaryColor: CupertinoColors.systemOrange,
              ),
              Button(
                onPressed: () async {
                  context.read<JournalCubit>().importPhoto();
                },
                label: 'Import Photo',
                primaryColor: CupertinoColors.systemOrange,
              ),
              Button(
                onPressed: () async {
                  context.read<JournalCubit>().importPhotos();
                },
                label: 'Import Photos',
                primaryColor: CupertinoColors.systemOrange,
              ),
            ],
          ),
        ),
      );
    });
  }
}
