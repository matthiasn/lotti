import 'package:flutter/foundation.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/main.dart';

class LinkService {
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  String? _linkToId;
  String? _linkFromId;

  void linkTo(String linkToId) {
    _linkToId = linkToId;
    debugPrint('linkTo $_linkToId}');
  }

  void linkFrom(String linkFromId) {
    _linkFromId = linkFromId;
    debugPrint('linkFromId $_linkFromId}');
  }
}
