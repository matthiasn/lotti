import 'package:lotti/classes/directed_relation.dart';
import 'package:lotti/classes/entry_link.dart';

/// The phrases that mark a sentence as talking about other work, for one
/// relationship, in each of the app's languages.
///
/// A phrase is matched as whole words, ignoring case; a space or hyphen in it
/// matches any run of spaces and hyphens, so "follow-up to" also matches
/// "follow up to". Phrases are deliberately multi-word wherever a single word
/// would also be ordinary prose ("duplicates" in "remove duplicates", "fixes"
/// in "fixes the door"): a cue only starts a search, and a wrong one costs a
/// search, but a cue that picks the wrong relationship costs the user a
/// rejection.
class PriorWorkCueSet {
  const PriorWorkCueSet(this.relation, this.phrasesByLanguage);

  /// The relationship a sentence with one of these phrases suggests, read
  /// with the task the sentence belongs to as its subject.
  final DirectedRelation relation;

  /// Phrases keyed by language code. Every language is matched against every
  /// text: entries are not tagged with a language, and the phrases are long
  /// enough not to collide across languages.
  final Map<String, List<String>> phrasesByLanguage;

  /// Every phrase, all languages together.
  Iterable<String> get phrases => phrasesByLanguage.values.expand((p) => p);
}

/// "This task follows up on …"
const followsUpCues = PriorWorkCueSet(
  DirectedRelation(EntryLinkType.followsUp),
  {
    'en': [
      'follow-up to',
      'follow-up on',
      'follow-up from',
      'following up on',
      'continuation of',
      'continuing the',
      'continues the',
      'picks up where',
      'building on',
      'builds on',
      'next step after',
    ],
    'de': [
      'Fortsetzung von',
      'Fortsetzung der',
      'Fortsetzung des',
      'Folgeaufgabe zu',
      'Folgeaufgabe von',
      'knüpft an',
      'anknüpfend an',
      'aufbauend auf',
      'baut auf',
    ],
    'fr': [
      'fait suite à',
      'faisant suite à',
      'dans la continuité de',
      'suite de',
      'prolonge le',
      'prolonge la',
    ],
    'es': [
      'continuación de',
      'seguimiento de',
      'a raíz de',
      'retoma el',
      'retoma la',
    ],
    'it': [
      'continuazione di',
      'seguito di',
      'in seguito a',
      'riprende il',
      'riprende la',
    ],
    'nl': [
      'vervolg op',
      'vervolg van',
      'voortzetting van',
      'bouwt voort op',
    ],
    'pt': [
      'continuação de',
      'seguimento de',
      'na sequência de',
      'dá seguimento a',
    ],
    'cs': ['navazuje na', 'navázání na', 'pokračování'],
    'ro': ['continuarea', 'ca urmare a', 'în urma'],
    'da': ['opfølgning på', 'fortsættelse af', 'bygger videre på'],
    'sv': ['uppföljning av', 'fortsättning på', 'bygger vidare på'],
  },
);

/// "This task is blocked by …"
const blockedByCues = PriorWorkCueSet(
  DirectedRelation(EntryLinkType.blocks, inverse: true),
  {
    'en': [
      'blocked by',
      'waiting on',
      'waiting for',
      'depends on',
      'dependent on',
      "can't start until",
      'cannot start until',
      "can't continue until",
      'cannot continue until',
    ],
    'de': [
      'blockiert durch',
      'blockiert von',
      'wartet auf',
      'warten auf',
      'hängt ab von',
      'abhängig von',
    ],
    'fr': ['bloqué par', 'bloquée par', 'en attente de', 'dépend de'],
    'es': [
      'bloqueado por',
      'bloqueada por',
      'a la espera de',
      'esperando a',
      'depende de',
    ],
    'it': ['bloccato da', 'bloccata da', 'in attesa di', 'dipende da'],
    'nl': [
      'geblokkeerd door',
      'wacht op',
      'wachten op',
      'afhankelijk van',
      'hangt af van',
    ],
    'pt': ['bloqueado por', 'bloqueada por', 'à espera de', 'aguardando'],
    'cs': ['blokováno', 'čeká na', 'čekáme na', 'závisí na'],
    'ro': ['blocat de', 'blocată de', 'în așteptarea', 'depinde de'],
    'da': ['blokeret af', 'venter på', 'afhænger af', 'afhængig af'],
    'sv': ['blockerad av', 'väntar på', 'beroende av'],
  },
);

/// "This task blocks …"
const blocksCues = PriorWorkCueSet(DirectedRelation(EntryLinkType.blocks), {
  'en': [
    'is blocking',
    'prerequisite for',
    'must be done before',
    'needed before',
    'has to happen before',
  ],
  'de': ['Voraussetzung für', 'Vorbedingung für', 'blockiert gerade'],
  'fr': ['prérequis pour', 'préalable à', 'condition préalable'],
  'es': ['requisito previo para', 'prerrequisito para'],
  'it': ['prerequisito per', 'propedeutico a'],
  'nl': ['voorwaarde voor', 'blokkeert nu'],
  'pt': ['pré-requisito para', 'pré-requisito de'],
  'cs': ['předpoklad pro', 'podmínka pro'],
  'ro': ['precondiție pentru', 'condiție prealabilă pentru'],
  'da': ['forudsætning for'],
  'sv': ['förutsättning för'],
});

/// "This task duplicates …"
const duplicatesCues = PriorWorkCueSet(
  DirectedRelation(EntryLinkType.duplicates),
  {
    'en': [
      'duplicate of',
      'dupe of',
      'already tracked in',
      'already tracked by',
      'already covered by',
      'already covered in',
    ],
    'de': [
      'Duplikat von',
      'Duplikat zu',
      'doppelt mit',
      'bereits erfasst in',
      'schon erfasst in',
    ],
    'fr': ['doublon de', 'déjà suivi dans', 'déjà couvert par'],
    'es': ['duplicado de', 'ya registrado en', 'ya cubierto por'],
    'it': ['duplicato di', 'già tracciato in', 'già coperto da'],
    'nl': ['duplicaat van', 'al opgenomen in', 'al gedekt door'],
    'pt': [
      'duplicado de',
      'duplicata de',
      'já registado em',
      'já registrado em',
    ],
    'cs': ['duplikát', 'už evidováno v'],
    'ro': ['duplicat al', 'duplicat de', 'deja urmărit în'],
    'da': ['dublet af', 'duplikat af', 'allerede dækket af'],
    'sv': ['dubblett av', 'duplikat av', 'redan täckt av'],
  },
);

/// "This task fixes …"
const fixesCues = PriorWorkCueSet(DirectedRelation(EntryLinkType.fixes), {
  'en': [
    'fix for',
    'bugfix for',
    'fixes the bug',
    'fixes the issue',
    'fixes the regression',
    'regression fix for',
  ],
  'de': [
    'Fix für',
    'Bugfix für',
    'behebt den Fehler',
    'behebt das Problem',
    'Korrektur für',
  ],
  'fr': [
    'correctif pour',
    'corrige le bug',
    'corrige le problème',
    "corrige l'erreur",
  ],
  'es': [
    'corrección para',
    'corrige el error',
    'corrige el fallo',
    'arreglo para',
  ],
  'it': [
    'correzione per',
    'corregge il bug',
    "corregge l'errore",
    'risolve il bug',
  ],
  'nl': ['fix voor', 'bugfix voor', 'lost de bug op', 'verhelpt de fout'],
  'pt': ['correção para', 'corrige o erro', 'corrige o bug'],
  'cs': ['oprava pro', 'opravuje chybu'],
  'ro': ['remediere pentru', 'corectează eroarea', 'repară eroarea'],
  'da': ['rettelse til', 'retter fejlen'],
  'sv': ['rättning av', 'åtgärdar felet', 'fix för'],
});

/// "This task supersedes …"
const supersedesCues = PriorWorkCueSet(
  DirectedRelation(EntryLinkType.supersedes),
  {
    'en': [
      'supersedes',
      'obsoletes',
      'makes obsolete',
      'replacement for',
      'replaces the old',
      'replaces the previous',
    ],
    'de': [
      'ersetzt die alte',
      'ersetzt den alten',
      'ersetzt das alte',
      'Ersatz für',
      'macht überflüssig',
    ],
    'fr': ["remplace l'ancien", "remplace l'ancienne", 'rend obsolète'],
    'es': [
      'sustituye al anterior',
      'reemplaza al anterior',
      'deja obsoleto',
    ],
    'it': [
      'sostituisce il precedente',
      'sostituisce la precedente',
      'rende obsoleto',
    ],
    'nl': ['vervangt de oude', 'vervangt het oude', 'maakt overbodig'],
    'pt': ['substitui o antigo', 'substitui a antiga', 'torna obsoleto'],
    'cs': ['nahrazuje původní', 'nahrazuje starý'],
    'ro': ['înlocuiește vechiul', 'înlocuiește vechea'],
    'da': ['erstatter den gamle', 'erstatter det gamle'],
    'sv': ['ersätter den gamla', 'ersätter det gamla'],
  },
);

/// "This task relates to …" — the sentence speaks of earlier work without
/// saying how it relates.
const relatesToCues = PriorWorkCueSet(DirectedRelation(EntryLinkType.basic), {
  'en': [
    'like last time',
    'last time',
    'as before',
    'as we did',
    'we already',
    'I already',
    'did this before',
    'done before',
    'previously',
    'earlier task',
    'earlier work',
    'similar to',
    'related to',
    'see also',
    'same issue as',
    'same problem as',
    'same bug as',
    'as discussed in',
    'back when',
    'remember when',
    'the other task',
    'last week',
    'last month',
    'last sprint',
  ],
  'de': [
    'wie letztes Mal',
    'letztes Mal',
    'wie zuvor',
    'wie vorher',
    'wie damals',
    'schon mal',
    'schon einmal',
    'bereits gemacht',
    'bereits erledigt',
    'ähnlich wie',
    'siehe auch',
    'im Zusammenhang mit',
    'bezieht sich auf',
    'gleiches Problem wie',
    'dasselbe Problem wie',
    'die andere Aufgabe',
    'letzte Woche',
    'letzten Monat',
    'vorige Woche',
    'damals',
  ],
  'fr': [
    'comme la dernière fois',
    'la dernière fois',
    'comme avant',
    'déjà fait',
    'déjà essayé',
    'précédemment',
    'similaire à',
    'lié à',
    'voir aussi',
    'même problème que',
    'la semaine dernière',
    'le mois dernier',
    "l'autre tâche",
  ],
  'es': [
    'como la última vez',
    'la última vez',
    'como antes',
    'ya lo hicimos',
    'anteriormente',
    'similar a',
    'relacionado con',
    'ver también',
    'mismo problema que',
    'la semana pasada',
    'el mes pasado',
    'la otra tarea',
  ],
  'it': [
    "come l'ultima volta",
    "l'ultima volta",
    'come prima',
    'già fatto',
    'in precedenza',
    'simile a',
    'collegato a',
    'legato a',
    'vedi anche',
    'stesso problema di',
    'la settimana scorsa',
    'il mese scorso',
    "l'altra attività",
  ],
  'nl': [
    'zoals vorige keer',
    'vorige keer',
    'eerder gedaan',
    'al eens',
    'vergelijkbaar met',
    'gerelateerd aan',
    'zie ook',
    'hetzelfde probleem als',
    'vorige week',
    'vorige maand',
    'de andere taak',
  ],
  'pt': [
    'como da última vez',
    'da última vez',
    'como antes',
    'já fizemos',
    'anteriormente',
    'semelhante a',
    'relacionado com',
    'ver também',
    'mesmo problema que',
    'na semana passada',
    'no mês passado',
    'a outra tarefa',
  ],
  'cs': [
    'jako minule',
    'minule',
    'jako předtím',
    'už jsme',
    'už jsem',
    'podobně jako',
    'souvisí s',
    'viz také',
    'stejný problém jako',
    'minulý týden',
    'minulý měsíc',
    'ten druhý úkol',
  ],
  'ro': [
    'ca data trecută',
    'data trecută',
    'ca înainte',
    'am mai făcut',
    'similar cu',
    'legat de',
    'vezi și',
    'aceeași problemă ca',
    'săptămâna trecută',
    'luna trecută',
    'cealaltă sarcină',
  ],
  'da': [
    'som sidst',
    'sidste gang',
    'som før',
    'allerede gjort',
    'relateret til',
    'se også',
    'samme problem som',
    'sidste uge',
    'sidste måned',
    'den anden opgave',
  ],
  'sv': [
    'som förra gången',
    'förra gången',
    'som tidigare',
    'redan gjort',
    'relaterat till',
    'se även',
    'samma problem som',
    'förra veckan',
    'förra månaden',
    'den andra uppgiften',
  ],
});

/// The cue sets in the order they are tried: every relationship that names
/// how the work relates before the plain "relates to", which only says that
/// it does.
const priorWorkCueSets = <PriorWorkCueSet>[
  blockedByCues,
  blocksCues,
  duplicatesCues,
  fixesCues,
  supersedesCues,
  followsUpCues,
  relatesToCues,
];
