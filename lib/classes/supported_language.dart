import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum SupportedLanguage {
  ar('ar', 'Arabic'),
  bn('bn', 'Bengali'),
  bg('bg', 'Bulgarian'),
  zh('zh', 'Chinese'),
  hr('hr', 'Croatian'),
  cs('cs', 'Czech'),
  da('da', 'Danish'),
  nl('nl', 'Dutch'),
  en('en', 'English'),
  et('et', 'Estonian'),
  fi('fi', 'Finnish'),
  fr('fr', 'French'),
  de('de', 'German'),
  el('el', 'Greek'),
  he('he', 'Hebrew'),
  hi('hi', 'Hindi'),
  ig('ig', 'Igbo'),
  hu('hu', 'Hungarian'),
  id('id', 'Indonesian'),
  it('it', 'Italian'),
  ja('ja', 'Japanese'),
  ko('ko', 'Korean'),
  lv('lv', 'Latvian'),
  lt('lt', 'Lithuanian'),
  no('no', 'Norwegian'),
  pl('pl', 'Polish'),
  pt('pt', 'Portuguese'),
  ro('ro', 'Romanian'),
  ru('ru', 'Russian'),
  sr('sr', 'Serbian'),
  sk('sk', 'Slovak'),
  sl('sl', 'Slovenian'),
  es('es', 'Spanish'),
  sw('sw', 'Swahili'),
  sv('sv', 'Swedish'),
  th('th', 'Thai'),
  tw('tw', 'Twi'),
  tr('tr', 'Turkish'),
  uk('uk', 'Ukrainian'),
  vi('vi', 'Vietnamese'),
  pcm('pcm', 'Nigerian Pidgin'),
  yo('yo', 'Yoruba');

  const SupportedLanguage(this.code, this.name);
  final String code;
  final String name;

  static final Map<String, SupportedLanguage> _byCode = {
    for (var lang in values) lang.code: lang,
  };

  static SupportedLanguage? fromCode(String code) {
    return _byCode[code];
  }

  String localizedName(BuildContext context) {
    return switch (this) {
      SupportedLanguage.ar => context.messages.taskLanguageArabic,
      SupportedLanguage.bn => context.messages.taskLanguageBengali,
      SupportedLanguage.bg => context.messages.taskLanguageBulgarian,
      SupportedLanguage.zh => context.messages.taskLanguageChinese,
      SupportedLanguage.hr => context.messages.taskLanguageCroatian,
      SupportedLanguage.cs => context.messages.taskLanguageCzech,
      SupportedLanguage.da => context.messages.taskLanguageDanish,
      SupportedLanguage.nl => context.messages.taskLanguageDutch,
      SupportedLanguage.en => context.messages.taskLanguageEnglish,
      SupportedLanguage.et => context.messages.taskLanguageEstonian,
      SupportedLanguage.fi => context.messages.taskLanguageFinnish,
      SupportedLanguage.fr => context.messages.taskLanguageFrench,
      SupportedLanguage.de => context.messages.taskLanguageGerman,
      SupportedLanguage.el => context.messages.taskLanguageGreek,
      SupportedLanguage.he => context.messages.taskLanguageHebrew,
      SupportedLanguage.hi => context.messages.taskLanguageHindi,
      SupportedLanguage.ig => context.messages.taskLanguageIgbo,
      SupportedLanguage.hu => context.messages.taskLanguageHungarian,
      SupportedLanguage.id => context.messages.taskLanguageIndonesian,
      SupportedLanguage.it => context.messages.taskLanguageItalian,
      SupportedLanguage.ja => context.messages.taskLanguageJapanese,
      SupportedLanguage.ko => context.messages.taskLanguageKorean,
      SupportedLanguage.lv => context.messages.taskLanguageLatvian,
      SupportedLanguage.lt => context.messages.taskLanguageLithuanian,
      SupportedLanguage.no => context.messages.taskLanguageNorwegian,
      SupportedLanguage.pl => context.messages.taskLanguagePolish,
      SupportedLanguage.pt => context.messages.taskLanguagePortuguese,
      SupportedLanguage.ro => context.messages.taskLanguageRomanian,
      SupportedLanguage.ru => context.messages.taskLanguageRussian,
      SupportedLanguage.sr => context.messages.taskLanguageSerbian,
      SupportedLanguage.sk => context.messages.taskLanguageSlovak,
      SupportedLanguage.sl => context.messages.taskLanguageSlovenian,
      SupportedLanguage.es => context.messages.taskLanguageSpanish,
      SupportedLanguage.sw => context.messages.taskLanguageSwahili,
      SupportedLanguage.sv => context.messages.taskLanguageSwedish,
      SupportedLanguage.th => context.messages.taskLanguageThai,
      SupportedLanguage.tw => context.messages.taskLanguageTwi,
      SupportedLanguage.tr => context.messages.taskLanguageTurkish,
      SupportedLanguage.uk => context.messages.taskLanguageUkrainian,
      SupportedLanguage.vi => context.messages.taskLanguageVietnamese,
      SupportedLanguage.pcm => context.messages.taskLanguageNigerianPidgin,
      SupportedLanguage.yo => context.messages.taskLanguageYoruba,
    };
  }
}
