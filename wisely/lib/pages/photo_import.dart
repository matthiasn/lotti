import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
    void _importPhotos() async {
      final ImagePicker _picker = ImagePicker();
      // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      // final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      final List<XFile>? images = await _picker.pickMultiImage();
      if (images != null) {
        context.read<JournalCubit>().importPhotos(images);
      }
    }

    return BlocBuilder<JournalCubit, JournalState>(
        builder: (BuildContext context, JournalState state) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Button(
                onPressed: _importPhotos,
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
