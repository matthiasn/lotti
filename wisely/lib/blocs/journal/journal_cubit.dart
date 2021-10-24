import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/utils/image_utils.dart';

import 'journal_state.dart';

class JournalCubit extends Cubit<JournalState> {
  JournalCubit() : super(JournalState()) {
    print('Hello from JournalCubit');
  }

  Future<void> importPhoto() async {
    final ImagePicker _picker = ImagePicker();
    // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    // final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    // final List<XFile>? images = await _picker.pickMultiImage(
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 2048,
      maxWidth: 2048,
      imageQuality: 80,
    );
    if (image != null) {
      print('JournalCubit importPhoto $image');
      print('JournalCubit importPhoto path ${image.path}');
      print('JournalCubit importPhoto name ${image.name}');
      print('JournalCubit importPhoto mimeType ${image.mimeType}');
      print('JournalCubit importPhoto length ${await image.length()}');

      final docDir = await getApplicationDocumentsDirectory();
      const String directory = 'images';
      final String filePath = '${docDir.path}/$directory/${image.name}';
      await File(filePath).parent.create(recursive: true);
      await image.saveTo(filePath);
      await printExif(await image.readAsBytes());
      await printGeolocation(await image.readAsBytes());
    }
  }
}
