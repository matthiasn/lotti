import 'package:beamer/beamer.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:lotti/blocs/nav/nav_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

class NavCubit extends Cubit<NavState> {
  NavCubit({
    required this.index,
    required this.path,
    required this.beamerDelegates,
  }) : super(
          NavState(
            index: index,
            path: path,
            beamerDelegates: beamerDelegates,
          ),
        );

  String path;
  int index;
  List<BeamerDelegate> beamerDelegates;

  void emitState() {
    emit(
      state.copyWith(
        index: index,
        path: path,
      ),
    );
  }

  void setPath(String uriString) {
    debugPrint('setPath $uriString');
    path = uriString;

    if (uriString.startsWith('/dashboards')) {
      setIndex(0);
    }
    if (uriString.startsWith('/journal')) {
      setIndex(1);
    }
    if (uriString.startsWith('/tasks')) {
      setIndex(2);
    }
    if (uriString.startsWith('/settings')) {
      setIndex(3);
    }

    emitState();
  }

  void setIndex(int newIndex) {
    index = newIndex;
    debugPrint('setIndex $index');
    beamerDelegates[index].update(rebuild: false);
    emitState();
    getIt<NavService>().setIndex(newIndex);
  }

  void beamToNamed(String path) {
    setPath(path);
    beamerDelegates[index].beamToNamed(path);
    getIt<NavService>().beamToNamed(path);
  }
}
