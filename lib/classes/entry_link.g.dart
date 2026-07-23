// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'entry_link.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BasicLink _$BasicLinkFromJson(Map<String, dynamic> json) => BasicLink(
  id: json['id'] as String,
  fromId: json['fromId'] as String,
  toId: json['toId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  vectorClock: json['vectorClock'] == null
      ? null
      : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
  hidden: json['hidden'] as bool?,
  collapsed: json['collapsed'] as bool?,
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$BasicLinkToJson(BasicLink instance) => <String, dynamic>{
  'id': instance.id,
  'fromId': instance.fromId,
  'toId': instance.toId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'vectorClock': instance.vectorClock,
  'hidden': instance.hidden,
  'collapsed': instance.collapsed,
  'deletedAt': instance.deletedAt?.toIso8601String(),
  'runtimeType': instance.$type,
};

RatingLink _$RatingLinkFromJson(Map<String, dynamic> json) => RatingLink(
  id: json['id'] as String,
  fromId: json['fromId'] as String,
  toId: json['toId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  vectorClock: json['vectorClock'] == null
      ? null
      : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
  hidden: json['hidden'] as bool?,
  collapsed: json['collapsed'] as bool?,
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$RatingLinkToJson(RatingLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

ProjectLink _$ProjectLinkFromJson(Map<String, dynamic> json) => ProjectLink(
  id: json['id'] as String,
  fromId: json['fromId'] as String,
  toId: json['toId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  vectorClock: json['vectorClock'] == null
      ? null
      : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
  hidden: json['hidden'] as bool?,
  collapsed: json['collapsed'] as bool?,
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ProjectLinkToJson(ProjectLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

BlocksLink _$BlocksLinkFromJson(Map<String, dynamic> json) => BlocksLink(
  id: json['id'] as String,
  fromId: json['fromId'] as String,
  toId: json['toId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  vectorClock: json['vectorClock'] == null
      ? null
      : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
  hidden: json['hidden'] as bool?,
  collapsed: json['collapsed'] as bool?,
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$BlocksLinkToJson(BlocksLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

FollowsUpLink _$FollowsUpLinkFromJson(Map<String, dynamic> json) =>
    FollowsUpLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      hidden: json['hidden'] as bool?,
      collapsed: json['collapsed'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$FollowsUpLinkToJson(FollowsUpLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

DuplicatesLink _$DuplicatesLinkFromJson(Map<String, dynamic> json) =>
    DuplicatesLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      hidden: json['hidden'] as bool?,
      collapsed: json['collapsed'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DuplicatesLinkToJson(DuplicatesLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };

FixesLink _$FixesLinkFromJson(Map<String, dynamic> json) => FixesLink(
  id: json['id'] as String,
  fromId: json['fromId'] as String,
  toId: json['toId'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  vectorClock: json['vectorClock'] == null
      ? null
      : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
  hidden: json['hidden'] as bool?,
  collapsed: json['collapsed'] as bool?,
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$FixesLinkToJson(FixesLink instance) => <String, dynamic>{
  'id': instance.id,
  'fromId': instance.fromId,
  'toId': instance.toId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'vectorClock': instance.vectorClock,
  'hidden': instance.hidden,
  'collapsed': instance.collapsed,
  'deletedAt': instance.deletedAt?.toIso8601String(),
  'runtimeType': instance.$type,
};

SupersedesLink _$SupersedesLinkFromJson(Map<String, dynamic> json) =>
    SupersedesLink(
      id: json['id'] as String,
      fromId: json['fromId'] as String,
      toId: json['toId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      vectorClock: json['vectorClock'] == null
          ? null
          : VectorClock.fromJson(json['vectorClock'] as Map<String, dynamic>),
      hidden: json['hidden'] as bool?,
      collapsed: json['collapsed'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$SupersedesLinkToJson(SupersedesLink instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fromId': instance.fromId,
      'toId': instance.toId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'vectorClock': instance.vectorClock,
      'hidden': instance.hidden,
      'collapsed': instance.collapsed,
      'deletedAt': instance.deletedAt?.toIso8601String(),
      'runtimeType': instance.$type,
    };
