import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wisely/blocs/journal/journal_image_cubit.dart';
import 'package:wisely/blocs/journal/journal_image_state.dart';
import 'package:wisely/widgets/buttons.dart';

class PhotoImportPage extends StatelessWidget {
  const PhotoImportPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JournalImageCubit, JournalImageState>(
        builder: (BuildContext context, JournalImageState state) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Button('Pick Assets', onPressed: () async {
                context.read<JournalImageCubit>().pickImageAssets(context);
              }, primaryColor: CupertinoColors.systemOrange),
            ],
          ),
        ),
      );
    });
  }
}
