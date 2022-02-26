import 'package:flutter/services.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';

class LinkService {
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();

  String? _linkToId;
  String? _linkFromId;

  void createLink() async {
    if (_linkFromId != null && _linkToId != null) {
      HapticFeedback.heavyImpact();

      await _persistenceLogic.createLink(
        fromId: _linkFromId!,
        toId: _linkToId!,
      );

      Future.delayed(const Duration(minutes: 2)).then((_) {
        _linkFromId = null;
        _linkToId = null;
      });
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void linkTo(String linkToId) {
    _linkToId = linkToId;
    createLink();
  }

  void linkFrom(String linkFromId) {
    _linkFromId = linkFromId;
    createLink();
  }
}
