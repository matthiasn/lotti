import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'journal_state.dart';

class JournalCubit extends Cubit<JournalState> {
  JournalCubit() : super(JournalState()) {
    print('Hello from JournalCubit');
  }

  Future<void> importPhotos(List<XFile> images) async {
    print('JournalCubit importPhotos $images');
    for (final image in images) {
      print('JournalCubit importPhoto $image');
    }
  }
}
