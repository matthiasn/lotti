import 'package:lotti/features/demo/media/generated/demo_media_thumb_hashes.g.dart';
import 'package:lotti/features/demo/seed/demo_ids.dart';
import 'package:meta/meta.dart';

/// Public Cloudflare R2 origin used by the immutable demo-media catalog.
const demoMediaPublicBaseUrl =
    'https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev';

/// Immutable R2 prefix for the first rich Penguin Logistics media set.
const demoMediaR2Prefix = 'demo/penguin-logistics/v1';

/// Tenant-relative directory where downloaded demo media is materialized.
const demoMediaDirectory = 'demo_media/penguin_logistics/v1';

/// One immutable image in the Penguin Logistics R2 catalog.
///
/// The source remains exclusively in R2. On every demo-world startup the
/// media hydrator compares [sha256] with the tenant-local materialized file
/// and downloads only missing or corrupt assets in the background.
@immutable
class DemoMediaAsset {
  const DemoMediaAsset({
    required this.id,
    required this.fileName,
    required this.sha256,
    required this.taskId,
    required this.categoryId,
    required this.capturedDaysAgo,
    required this.capturedHour,
    required this.isCover,
    this.captionEnglish,
    this.captionGerman,
  }) : assert(
         (captionEnglish == null) == (captionGerman == null),
         'Localized captions must be supplied as an English/German pair.',
       );

  /// Stable journal-image UUID used by seeded task cover/link wiring.
  final String id;

  /// File name shared by the R2 object and tenant-local materialization.
  final String fileName;

  /// Lowercase SHA-256 digest of the published object.
  final String sha256;

  /// Seeded task that owns this image.
  final String taskId;

  /// Category inherited by the seeded image entity.
  final String categoryId;

  /// How far before seed time this image was captured.
  final int capturedDaysAgo;

  /// Local wall-clock hour used for the relative capture timestamp.
  final int capturedHour;

  /// Whether this image is the owning task's cover.
  final bool isCover;

  /// Optional attachment caption passed through the demo seed translator.
  final String? captionEnglish;
  final String? captionGerman;

  /// Base64 ThumbHash of the object — the blurred stand-in the app draws
  /// while the file downloads — or null when the backfill has not seen this
  /// [sha256] yet. Keyed by digest, so a replaced object loses its stale
  /// hash by itself; `make demo_media_thumb_hashes` fills the gap.
  String? get thumbHash => demoMediaThumbHashes[sha256];

  String get objectKey => '$demoMediaR2Prefix/$fileName';

  Uri get uri => Uri.parse('$demoMediaPublicBaseUrl/$objectKey');

  String get relativePath => '$demoMediaDirectory/$fileName';

  /// `ImageData.imageDirectory` notation, including leading/trailing slash.
  String get imageDirectory => '/$demoMediaDirectory/';

  String? caption(String Function(String, String) translate) {
    final english = captionEnglish;
    final german = captionGerman;
    return english == null || german == null
        ? null
        : translate(english, german);
  }
}

const _penguinOps = 'manual-penguin-ops';
const _habitatEngineering = 'manual-habitat-engineering';
const _logisticsSupply = 'manual-logistics-supply';

DemoMediaAsset _cover({
  required String idSeed,
  required String taskSeed,
  required String fileName,
  required String sha256,
  required int capturedDaysAgo,
  String categoryId = _penguinOps,
  int capturedHour = 10,
}) => DemoMediaAsset(
  id: demoUuid(idSeed),
  fileName: fileName,
  sha256: sha256,
  taskId: demoUuid(taskSeed),
  categoryId: categoryId,
  capturedDaysAgo: capturedDaysAgo,
  capturedHour: capturedHour,
  isCover: true,
);

DemoMediaAsset _attachment({
  required String idSeed,
  required String taskSeed,
  required String fileName,
  required String sha256,
  required int capturedDaysAgo,
  String? captionEnglish,
  String? captionGerman,
  String categoryId = _penguinOps,
  int capturedHour = 14,
}) {
  final defaultCaption = _taskCaption(taskSeed);
  return DemoMediaAsset(
    id: demoUuid(idSeed),
    fileName: fileName,
    sha256: sha256,
    taskId: demoUuid(taskSeed),
    categoryId: categoryId,
    capturedDaysAgo: capturedDaysAgo,
    capturedHour: capturedHour,
    isCover: false,
    captionEnglish: captionEnglish ?? defaultCaption.$1,
    captionGerman: captionGerman ?? defaultCaption.$2,
  );
}

(String, String) _taskCaption(String taskSeed) => switch (taskSeed) {
  'demo-tutorial-first-steps' => ('Your first mission', 'Deine erste Mission'),
  'task-emperor-penguin-roll-call' => (
    'Emperor penguin roll call',
    'Kaiserpinguine durchzählen',
  ),
  'task-orbital-habitat' => (
    'Inspect orbital penguin habitat',
    'Pinguin-Habitat im Orbit inspizieren',
  ),
  'task-project-waddle-launch-review' => (
    'Project Waddle launch review',
    'Startprüfung für Project Waddle',
  ),
  'task-coffee-is-not-a-vegetable' => (
    'Lunch (coffee is not a vegetable)',
    'Mittagessen (Kaffee ist kein Gemüse)',
  ),
  'task-negotiate-sardine-futures' => (
    'Negotiate sardine futures',
    'Sardinen-Futures verhandeln',
  ),
  'task-zero-gravity-feeder' => (
    'Recalibrate the zero-gravity fish feeder',
    'Schwerelosen Fischfütterer neu kalibrieren',
  ),
  'task-sardine-cargo' => (
    'Confirm the interplanetary sardine cargo pods',
    'Interplanetare Sardinen-Frachtkapseln bestätigen',
  ),
  'task-penguin-passenger' => (
    'Ask Legal whether a penguin is a passenger',
    'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
  ),
  'task-walk-without-headset' => (
    'Walk without a headset',
    'Spaziergang ohne Headset',
  ),
  'task-launch-comms-plan' => (
    'Draft the launch comms plan',
    'Kommunikationsplan entwerfen',
  ),
  'task-ice-pad-weather' => (
    'Check the ice-pad weather window',
    'Wetterfenster am Eisstartplatz prüfen',
  ),
  'task-cold-chain-audit' => (
    'Audit the cold-chain freezer logs',
    'Kühlketten-Protokolle prüfen',
  ),
  'task-launch-rehearsal' => (
    'Run the launch-day rehearsal',
    'Startprobe durchführen',
  ),
  'task-flight-suit-fitting' => (
    'Fit the penguin flight suits',
    'Pinguin-Fluganzüge anpassen',
  ),
  'task-air-scrubbers' => (
    'Replace the air scrubber cartridges',
    'Filterpatronen der Luftreinigung tauschen',
  ),
  'task-humidity-spike' => (
    'Trace the humidity spike in Bay C',
    'Feuchtigkeitsspitze in Bucht C aufspüren',
  ),
  'task-ice-rink-resurface' => (
    'Resurface the habitat ice rink',
    'Eisbahn im Habitat neu aufbereiten',
  ),
  'task-solar-array-tilt' => (
    'Retune the solar array tilt',
    'Neigung der Solarfläche justieren',
  ),
  'task-water-recycler' => (
    'Service the water recycler',
    'Wasseraufbereiter warten',
  ),
  'task-squid-pallet' => (
    'Find the missing squid pallet',
    'Verschwundene Tintenfisch-Palette finden',
  ),
  'task-krill-supplier' => (
    'Shortlist a second krill supplier',
    'Zweiten Krill-Lieferanten finden',
  ),
  'task-shuttle-manifest' => (
    'Reconcile the shuttle manifest',
    'Frachtliste des Shuttles abgleichen',
  ),
  'task-pod-seal-order' => (
    'Order replacement pod seals',
    'Ersatzdichtungen für Kapseln bestellen',
  ),
  'task-customs-europa' => (
    'Clear customs on Europa',
    'Zoll auf Europa erledigen',
  ),
  'task-colony-newsletter' => (
    'Write the colony newsletter',
    'Koloniebrief schreiben',
  ),
  'task-chick-daycare' => (
    'Refill the chick daycare rota',
    'Dienstplan der Kükenbetreuung füllen',
  ),
  'task-movie-night' => (
    'Pick the film for colony night',
    'Film für den Kolonieabend wählen',
  ),
  'task-tobogganing-league' => (
    'Restart the tobogganing league',
    'Rodel-Liga wieder starten',
  ),
  _ => throw ArgumentError.value(taskSeed, 'taskSeed'),
};

/// Complete immutable media fabric for the seeded Penguin Logistics world.
///
/// Each task owns exactly one cover. Selected hub tasks also own a second,
/// captioned evidence photo so task detail and graph views have richer
/// material to explore. IDs are deterministic and therefore safe to include
/// in the seed manifest's isolation boundary.
final List<DemoMediaAsset> demoMediaAssets = List.unmodifiable([
  _cover(
    idSeed: 'demo-tutorial-world-cover',
    taskSeed: 'demo-tutorial-first-steps',
    fileName: 'world_control_room_cats.webp',
    sha256: '31e46c329d9d06671cd89cbb5ae170a51375adb2143563c55f946211a69df855',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-habitat-cover',
    taskSeed: 'task-orbital-habitat',
    fileName: 'manual_task_cover_habitat.webp',
    sha256: '93fd246b1cd6d8bfaf2481c86c04183cf0b407629cfbea11c0ecc668f84cd7e7',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-roll-call-cover',
    taskSeed: 'task-emperor-penguin-roll-call',
    fileName: 'manual_task_cover_roll_call.webp',
    sha256: '990fc5cb2c1c1241762cef41328d85fc7aa20f68c087d175aa8980504e6363c7',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-launch-review-cover',
    taskSeed: 'task-project-waddle-launch-review',
    fileName: 'manual_task_cover_launch_review.webp',
    sha256: '049f8c2b61a00bff209e3724b45b1dd436b06b38f1268ad4b92b6d6d97de1d7d',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-lunch-cover',
    taskSeed: 'task-coffee-is-not-a-vegetable',
    fileName: 'manual_task_cover_lunch.webp',
    sha256: '59bc7eac24720315f9847c8c927b611c0efdfc2f9c540d35507f4a7da0c6610f',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-sardine-futures-cover',
    taskSeed: 'task-negotiate-sardine-futures',
    fileName: 'manual_task_cover_sardine_futures.webp',
    sha256: '729dc0a2ab2126e7988af7ead9988c1b7333e349a782ac2e365ed9916d55fbe5',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-feeder-cover',
    taskSeed: 'task-zero-gravity-feeder',
    fileName: 'manual_task_cover_feeder.webp',
    sha256: '9c77bd8bd2c3daaec79929eedb2cbe58c7ca76e1c9d18bac5887fdea7aa0ebb0',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-cargo-cover',
    taskSeed: 'task-sardine-cargo',
    fileName: 'manual_task_cover_cargo.webp',
    sha256: 'fdd13bba93d14f85ee7bdf779403710c90b5689089ed1aefd4cbefb8aa8f2427',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-legal-cover',
    taskSeed: 'task-penguin-passenger',
    fileName: 'manual_task_cover_legal.webp',
    sha256: '6afa475279cfe9cf9eb54b6d8407f03a469b391d9d848146d2f03c45d61da5df',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'manual-penguin-headset-walk-cover',
    taskSeed: 'task-walk-without-headset',
    fileName: 'manual_task_cover_headset_walk.webp',
    sha256: 'e98b257648a07310ee56db528b18a6f00e8a88cf45dde09e0395739a2df31957',
    capturedDaysAgo: 0,
  ),
  _cover(
    idSeed: 'demo-media-launch-comms-plan',
    taskSeed: 'task-launch-comms-plan',
    fileName: 'launch_comms_plan.webp',
    sha256: 'e93250bba1c101bf218579b968d2cee4aea6d6e6d1aedd28bffcb9e78d798624',
    capturedDaysAgo: 9,
  ),
  _cover(
    idSeed: 'demo-media-ice-pad-weather',
    taskSeed: 'task-ice-pad-weather',
    fileName: 'ice_pad_weather.webp',
    sha256: '8239ace9ebb8a691e20f527a1a181edc7a94ba217e036303e2f05e17b2d8c566',
    capturedDaysAgo: 2,
  ),
  _cover(
    idSeed: 'demo-media-cold-chain-audit',
    taskSeed: 'task-cold-chain-audit',
    fileName: 'cold_chain_audit.webp',
    sha256: '0c948606679f009fa0c2bf82623d97e1e2962421376225a9fc4997295ce2a9fa',
    capturedDaysAgo: 6,
  ),
  _cover(
    idSeed: 'demo-media-launch-rehearsal',
    taskSeed: 'task-launch-rehearsal',
    fileName: 'launch_rehearsal.webp',
    sha256: 'af4cfc718e8c7163b64170f6b0b82a3ca10c84d016529459babfcf02245bbb75',
    capturedDaysAgo: 4,
  ),
  _cover(
    idSeed: 'demo-media-flight-suit-fitting',
    taskSeed: 'task-flight-suit-fitting',
    fileName: 'flight_suit_fitting.webp',
    sha256: '6d2708f6f3a4958bf4faabc9a5fbe7ebd5943f787fe8d32425c6ee9ca802d804',
    capturedDaysAgo: 12,
  ),
  _cover(
    idSeed: 'demo-media-air-scrubber-cartridges',
    taskSeed: 'task-air-scrubbers',
    fileName: 'air_scrubber_cartridges.webp',
    sha256: '042704dba07947ff1731272fdbb6411a661ed60112a330ab46d5f4626bfefa95',
    capturedDaysAgo: 2,
    categoryId: _habitatEngineering,
  ),
  _cover(
    idSeed: 'demo-media-humidity-spike',
    taskSeed: 'task-humidity-spike',
    fileName: 'humidity_spike.webp',
    sha256: '7685959c73bfe5983f25429c4bbaf491b82cd4c10a74803d7d726cd10d7c162f',
    capturedDaysAgo: 3,
    categoryId: _habitatEngineering,
  ),
  _cover(
    idSeed: 'demo-media-ice-rink-resurface',
    taskSeed: 'task-ice-rink-resurface',
    fileName: 'ice_rink_resurface.webp',
    sha256: 'cb1097d2537e2a2b2e3c3c8f8ad4e85d8a00f93eed94d5f2a84bedf65a83ad0e',
    capturedDaysAgo: 15,
    categoryId: _habitatEngineering,
  ),
  _cover(
    idSeed: 'demo-media-solar-array-tilt',
    taskSeed: 'task-solar-array-tilt',
    fileName: 'solar_array_tilt.webp',
    sha256: '30647be9ea36f954e1454309436cad0deb7ee19ef4f85210b504c8c25a82df09',
    capturedDaysAgo: 6,
    categoryId: _habitatEngineering,
  ),
  _cover(
    idSeed: 'demo-media-water-recycler',
    taskSeed: 'task-water-recycler',
    fileName: 'water_recycler.webp',
    sha256: '99f2c1fa3d5a039782fa27c2a914ca75367b3ffb31c58f73da12ab6adf486e51',
    capturedDaysAgo: 6,
    categoryId: _habitatEngineering,
  ),
  _cover(
    idSeed: 'demo-media-missing-squid-pallet',
    taskSeed: 'task-squid-pallet',
    fileName: 'missing_squid_pallet.webp',
    sha256: '7a7d93d20228b0e393cc65c53cd705e5aab8dc16b70ddfb29f213e7029cd68d9',
    capturedDaysAgo: 5,
    categoryId: _logisticsSupply,
  ),
  _cover(
    idSeed: 'demo-media-krill-supplier',
    taskSeed: 'task-krill-supplier',
    fileName: 'krill_supplier.webp',
    sha256: '0e1cf0afb0e00b904b70d4e99dc9928e7ab9204892507b93bd70fef364738cc9',
    capturedDaysAgo: 7,
    categoryId: _logisticsSupply,
  ),
  _cover(
    idSeed: 'demo-media-shuttle-manifest',
    taskSeed: 'task-shuttle-manifest',
    fileName: 'shuttle_manifest.webp',
    sha256: '7b82bcdbf11635f26388d06cb59699cec0c97e5fcfde80932257a35bfd6f1fd4',
    capturedDaysAgo: 1,
    categoryId: _logisticsSupply,
  ),
  _cover(
    idSeed: 'demo-media-pod-seals',
    taskSeed: 'task-pod-seal-order',
    fileName: 'pod_seals.webp',
    sha256: '0b7e28dd2793e4c0bdf40e28e30a6bb235ff5f954b30e2bff7c53128fa993bf8',
    capturedDaysAgo: 10,
    categoryId: _logisticsSupply,
  ),
  _cover(
    idSeed: 'demo-media-europa-customs',
    taskSeed: 'task-customs-europa',
    fileName: 'europa_customs.webp',
    sha256: '364b0b50416a7bd734d76a99ff4e75071e62a897c0d28d63c4b477658ad6be87',
    capturedDaysAgo: 8,
    categoryId: _logisticsSupply,
  ),
  _cover(
    idSeed: 'demo-media-colony-newsletter',
    taskSeed: 'task-colony-newsletter',
    fileName: 'colony_newsletter.webp',
    sha256: '1fe42d2b7fba65755dd715b1b9b4335617d788bdfa002bb81330d4dba9c828f2',
    capturedDaysAgo: 4,
  ),
  _cover(
    idSeed: 'demo-media-chick-daycare',
    taskSeed: 'task-chick-daycare',
    fileName: 'chick_daycare.webp',
    sha256: '1e64cdb7b59fae37dbbe56f5259ec9495ead21a90e6ab85fd630ea3a55d31e85',
    capturedDaysAgo: 16,
  ),
  _cover(
    idSeed: 'demo-media-colony-movie-night',
    taskSeed: 'task-movie-night',
    fileName: 'colony_movie_night.webp',
    sha256: 'ca11c456bbbf90c39c80d4dba3ecec6615dead0a5e10e4bf73b939ce11110a3e',
    capturedDaysAgo: 18,
  ),
  _cover(
    idSeed: 'demo-media-tobogganing-league',
    taskSeed: 'task-tobogganing-league',
    fileName: 'tobogganing_league.webp',
    sha256: 'ec4f756254173014b87d38c0a709a7e559dba24ad32e9f124f5dec8e7523ff4b',
    capturedDaysAgo: 21,
  ),
  _attachment(
    idSeed: 'demo-media-habitat-seal-inspection-sheet',
    taskSeed: 'task-orbital-habitat',
    fileName: 'habitat_seal_inspection_sheet.webp',
    sha256: '29a82af07ba63abfe3d073aaf2245f82f12f4439cde55e7a17569e6cdc39f1a4',
    capturedDaysAgo: 1,
    captionEnglish: 'Bay A seals held 101.3 kPa all night.',
    captionGerman:
        'Die Dichtungen in Bucht A hielten die ganze Nacht 101,3 kPa.',
  ),
  _attachment(
    idSeed: 'demo-media-launch-trajectory-printout',
    taskSeed: 'task-project-waddle-launch-review',
    fileName: 'launch_trajectory_printout.webp',
    sha256: '7981eeaa9b3331c3660fe29e3a2b886d77ce03a01d4504ccaaed2f04f3db1588',
    capturedDaysAgo: 2,
    captionEnglish: 'The ice pad clears at 06:40 with a light crosswind.',
    captionGerman:
        'Der Eisstartplatz ist um 06:40 bei leichtem Seitenwind frei.',
  ),
  _attachment(
    idSeed: 'demo-media-fish-feeder-incident',
    taskSeed: 'task-zero-gravity-feeder',
    fileName: 'fish_feeder_incident.webp',
    sha256: '0c576c2b1f407f1cab83b81c14baa301e70443232c7f8473d337aa68a9c2e151',
    capturedDaysAgo: 1,
    captionEnglish: 'The feeder still aims lunch at Mission Control.',
    captionGerman:
        'Der Fütterer zielt das Mittagessen noch immer auf die Missionskontrolle.',
  ),
  _attachment(
    idSeed: 'demo-media-freezer-telemetry',
    taskSeed: 'task-cold-chain-audit',
    fileName: 'freezer_telemetry.webp',
    sha256: '9ee39707613cd7727ef46b9b32164a8a238d0721dfb705cd721a9d45454f066b',
    capturedDaysAgo: 6,
    captionEnglish: 'Freezer 3 logged a two-hour gap on Sunday.',
    captionGerman:
        'Kühlraum 3 hat am Sonntag eine zweistündige Lücke protokolliert.',
  ),
  _attachment(
    idSeed: 'demo-media-humidity-sensor-evidence',
    taskSeed: 'task-humidity-spike',
    fileName: 'humidity_sensor_evidence.webp',
    sha256: 'a73e3a67effb10ab435a37bd91f22ea7351c5cf22651c0cbfe964d75135cc722',
    capturedDaysAgo: 3,
    captionEnglish: 'Bay C is at 78% humidity, nine points up since Tuesday.',
    captionGerman:
        'Bucht C liegt bei 78 % Luftfeuchtigkeit, neun Punkte mehr als am Dienstag.',
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-missing-pallet-routing-still',
    taskSeed: 'task-squid-pallet',
    fileName: 'missing_pallet_routing_still.webp',
    sha256: '23809b59d66fa2d62e8c0c6e1f8137617cb0c3cabc63018f1964e71bb6575d14',
    capturedDaysAgo: 5,
    captionEnglish: 'Pallet 14 is not in bay two. Checking the cold ring next.',
    captionGerman:
        'Palette 14 ist nicht in Bucht zwei. Als Nächstes prüfen wir den Kühlring.',
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-europa-customs-declaration',
    taskSeed: 'task-customs-europa',
    fileName: 'europa_customs_declaration.webp',
    sha256: '6806c3c3da2941b5b1d19c0e9833901afc45d36ecaf26b89013c725ec1d46e03',
    capturedDaysAgo: 8,
    captionEnglish: 'Customs wants the pod seal certificates before Friday.',
    captionGerman:
        'Der Zoll will die Zertifikate der Kapseldichtungen vor Freitag.',
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-annotated-launch-script',
    taskSeed: 'task-launch-comms-plan',
    fileName: 'annotated_launch_script.webp',
    sha256: '6e2ad43908e90d1ef6f0eeac6344a7da5e320def133bb21b43547797f0a77add',
    capturedDaysAgo: 8,
    captionEnglish:
        'Mission Control wants fewer fish puns in the launch script.',
    captionGerman:
        'Die Missionskontrolle will weniger Fischwitze im Startskript.',
  ),
  _attachment(
    idSeed: 'demo-media-newsletter-front-page',
    taskSeed: 'task-colony-newsletter',
    fileName: 'newsletter_front_page.webp',
    sha256: 'c51ccf4e012e4f607dd39c4acbff6afed50df29601381065c7f2f08517ee8cef',
    capturedDaysAgo: 4,
    captionEnglish: 'The draft is done except for the launch section.',
    captionGerman: 'Der Entwurf ist fertig, bis auf den Abschnitt zum Start.',
  ),
  _attachment(
    idSeed: 'demo-media-toboggan-safety-report',
    taskSeed: 'task-tobogganing-league',
    fileName: 'toboggan_safety_report.webp',
    sha256: 'ab868967ca981ce292a00715035739fe2ca15acec1d28f91beff60e104892f06',
    capturedDaysAgo: 2,
    captionEnglish: 'One sprained flipper, so we need softer landings.',
    captionGerman:
        'Eine verstauchte Flosse, also brauchen wir weichere Landungen.',
  ),
  _attachment(
    idSeed: 'demo-media-habitat-pressure-hatch-photo',
    taskSeed: 'task-orbital-habitat',
    fileName: 'habitat_pressure_hatch_photo.webp',
    sha256: '1303d69b5453046c9e0901ceb26d34bff00739602457090703133c6aca6e2c3b',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-penguin-headcount-board',
    taskSeed: 'task-orbital-habitat',
    fileName: 'penguin_headcount_board.webp',
    sha256: '8105479fdfcca6346f71993073e2e8fed4e2c787de77baea4267638b4ec22a19',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-snack-manifest-flatlay',
    taskSeed: 'task-project-waddle-launch-review',
    fileName: 'snack_manifest_flatlay.webp',
    sha256: 'b5c8ee5cc5f33dfdf40112cfedcba57cff96aa924a7fb113fdc16ee9e96bc41f',
    capturedDaysAgo: 2,
  ),
  _attachment(
    idSeed: 'demo-media-fish-cursor-removal-photo',
    taskSeed: 'task-project-waddle-launch-review',
    fileName: 'fish_cursor_removal_photo.webp',
    sha256: '5b741db90c4a6797ad99a7440a36536ddd4c330050492c3c43a1ef14fb02e167',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-sardine-pod-dock-photo',
    taskSeed: 'task-sardine-cargo',
    fileName: 'sardine_pod_dock_photo.webp',
    sha256: '00a7a770cfc4f774e2eb5d4b3ea953dcd51b00a955a00eb3665e9e10a62d0695',
    capturedDaysAgo: 1,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-cold-chain-manifest-closeup',
    taskSeed: 'task-sardine-cargo',
    fileName: 'cold_chain_manifest_closeup.webp',
    sha256: 'd14dc9f517a0729d654c72cdbe2cf569c30740e854aee1301be3ab59af621dd3',
    capturedDaysAgo: 2,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-europa-shuttle-departure',
    taskSeed: 'task-sardine-cargo',
    fileName: 'europa_shuttle_departure.webp',
    sha256: '042927de8b2e5d80f438777686eb9906a20e8145974309c021bc33271f157943',
    capturedDaysAgo: 1,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-emperor-rollcall-manifest',
    taskSeed: 'task-emperor-penguin-roll-call',
    fileName: 'emperor_rollcall_manifest.webp',
    sha256: '2eee6a16b761ccefad89eaa4b7dbf0eab281a2e0881f6e3a5b563d95a5cbe012',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-oxygen-pack-inspection',
    taskSeed: 'task-emperor-penguin-roll-call',
    fileName: 'oxygen_pack_inspection.webp',
    sha256: '0dde70921df9017a4c68b14cf611618eaebd34a52ca46305033db19010f6684d',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-cargo-netting-sleeping-penguin',
    taskSeed: 'task-emperor-penguin-roll-call',
    fileName: 'cargo_netting_sleeping_penguin.webp',
    sha256: '8afe8db5a30028cb5c4e9d4c656329b3e78f877fd8da1f795d99a7a042335da8',
    capturedDaysAgo: 2,
  ),
  _attachment(
    idSeed: 'demo-media-feeder-calibration-target',
    taskSeed: 'task-zero-gravity-feeder',
    fileName: 'feeder_calibration_target.webp',
    sha256: 'cbbb4e9839cee74c8ea5eeb2f396edaa2eb390036f6317e7a9030f1ec1af867d',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-freezer-three-inspection-photo',
    taskSeed: 'task-cold-chain-audit',
    fileName: 'freezer_three_inspection_photo.webp',
    sha256: '10fd82ffb5a810b7ae9808ce175c68c722aa231a8453c9fae2a2246eaa5dfdab',
    capturedDaysAgo: 6,
  ),
  _attachment(
    idSeed: 'demo-media-bay-c-vent-condensation',
    taskSeed: 'task-humidity-spike',
    fileName: 'bay_c_vent_condensation.webp',
    sha256: '41419d85185801a209f4813d4e340fc0b61fea16483acef749ec792bf326633c',
    capturedDaysAgo: 3,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-cold-ring-search-map',
    taskSeed: 'task-squid-pallet',
    fileName: 'cold_ring_search_map.webp',
    sha256: '1302f15cf2bc2082e4970afe1c425cb8dbf44c90acf0256a0133f35299960ec2',
    capturedDaysAgo: 5,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-customs-queue-snapshot',
    taskSeed: 'task-customs-europa',
    fileName: 'customs_queue_snapshot.webp',
    sha256: '91f32b9c6ec8b1d203478a0062a983f1eacdff0dc8af3f65ac18c591b5d6dbd2',
    capturedDaysAgo: 8,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-mission-control-headset-board',
    taskSeed: 'task-launch-comms-plan',
    fileName: 'mission_control_headset_board.webp',
    sha256: '22bb8ea5218b20bb96f7b698470b7ce8cd33cf187099445971b29a17085296bd',
    capturedDaysAgo: 8,
  ),
  _attachment(
    idSeed: 'demo-media-editor-desk-fish-clips',
    taskSeed: 'task-colony-newsletter',
    fileName: 'editor_desk_fish_clips.webp',
    sha256: '10e46aa60bea7276e781ffa5df418834d7eb4ca865bbc1d150d58fc66e4da576',
    capturedDaysAgo: 4,
  ),
  _attachment(
    idSeed: 'demo-media-landing-pad-measurements',
    taskSeed: 'task-tobogganing-league',
    fileName: 'landing_pad_measurements.webp',
    sha256: '50a48da5b17c8bc06f7b01ade5acab767e934056ebc714f8b2fcb0df999efc9b',
    capturedDaysAgo: 2,
  ),
  _attachment(
    idSeed: 'demo-media-first-mission-dossier',
    taskSeed: 'demo-tutorial-first-steps',
    fileName: 'first_mission_dossier.webp',
    sha256: '2aadb909c0719b90e3dddad67008cc1bca0d666f839cd9221f9f26b2216ee134',
    capturedDaysAgo: 0,
  ),
  _attachment(
    idSeed: 'demo-media-demo-world-navigation-map',
    taskSeed: 'demo-tutorial-first-steps',
    fileName: 'demo_world_navigation_map.webp',
    sha256: 'b967b5e4e428cb103b4010c0c37620dd92960382e8eb1239ef03d3f4cf1e4802',
    capturedDaysAgo: 0,
  ),
  _attachment(
    idSeed: 'demo-media-orbital-cafeteria-tray',
    taskSeed: 'task-coffee-is-not-a-vegetable',
    fileName: 'orbital_cafeteria_tray.webp',
    sha256: 'fd5354d70ef20363e05266ddec31153e5dc8f9ea270283720bfbb2e9a0dad43e',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-nutrition-robot-incident-form',
    taskSeed: 'task-coffee-is-not-a-vegetable',
    fileName: 'nutrition_robot_incident_form.webp',
    sha256: '8233eb4b2b2fbd6538049689548c88865f4bf5c03e4e57bb2920bad044d40864',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-europa-fish-market-board',
    taskSeed: 'task-negotiate-sardine-futures',
    fileName: 'europa_fish_market_board.webp',
    sha256: '4ec08e6f5ca95489a84f21d1e1359a6702fd54a4620e42accf324bc281a544f8',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-sardine-contract-flipper-stamp',
    taskSeed: 'task-negotiate-sardine-futures',
    fileName: 'sardine_contract_flipper_stamp.webp',
    sha256: '23beea2b56c9eec2732d6b23d1f8f9e7eff92ce549ec7be8c98974cb8f52c43f',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-penguin-boarding-pass',
    taskSeed: 'task-penguin-passenger',
    fileName: 'penguin_boarding_pass.webp',
    sha256: '5952626c476e736332cf096deafc7d4b6fe0c7b41104fc8087c7f357c0010c8e',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-legal-species-flowchart',
    taskSeed: 'task-penguin-passenger',
    fileName: 'legal_species_flowchart.webp',
    sha256: '41a05db625afe7ccb21a790afa506b545375e8a6d1019bf350903621a39af126',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-ice-garden-quiet-walk',
    taskSeed: 'task-walk-without-headset',
    fileName: 'ice_garden_quiet_walk.webp',
    sha256: '6dcfc101facab98b1dd052b4f0a4fc11a31c957d090489add6ef12d1d3337b3d',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-headset-left-on-bench',
    taskSeed: 'task-walk-without-headset',
    fileName: 'headset_left_on_bench.webp',
    sha256: 'a854dbb24ff32dbcf825c9e6eac60f51b7ffef50d21e32790e3353b2bf0427e3',
    capturedDaysAgo: 1,
  ),
  _attachment(
    idSeed: 'demo-media-ice-pad-windsock',
    taskSeed: 'task-ice-pad-weather',
    fileName: 'ice_pad_windsock.webp',
    sha256: '65920145693dd736f6ceef878d098f46a53e05e63452f1dc6482d4909c650bf2',
    capturedDaysAgo: 2,
  ),
  _attachment(
    idSeed: 'demo-media-orbital-weather-station-readout',
    taskSeed: 'task-ice-pad-weather',
    fileName: 'orbital_weather_station_readout.webp',
    sha256: '136a2a30c008d3eb79c925cf567cdcbf058a86f2a2458f9e97c3a3a9dcd1a378',
    capturedDaysAgo: 2,
  ),
  _attachment(
    idSeed: 'demo-media-rehearsal-boarding-timeline',
    taskSeed: 'task-launch-rehearsal',
    fileName: 'rehearsal_boarding_timeline.webp',
    sha256: '19c3502aeb4d8ea45fa8cbe482d5904f584355b44753ce41088414f362bc9edf',
    capturedDaysAgo: 4,
  ),
  _attachment(
    idSeed: 'demo-media-rehearsal-crew-group-photo',
    taskSeed: 'task-launch-rehearsal',
    fileName: 'rehearsal_crew_group_photo.webp',
    sha256: '969af90f8629fe76bfcd0cf15268e6900adbbbe007b4b09e082c6bf9246b110c',
    capturedDaysAgo: 4,
  ),
  _attachment(
    idSeed: 'demo-media-flipper-measurement-chart',
    taskSeed: 'task-flight-suit-fitting',
    fileName: 'flipper_measurement_chart.webp',
    sha256: '2d86f5cbb98955df5f9abe1c59d16f18b9485035d7a1abf8fd3baa6445e716cd',
    capturedDaysAgo: 12,
  ),
  _attachment(
    idSeed: 'demo-media-flight-suit-rack',
    taskSeed: 'task-flight-suit-fitting',
    fileName: 'flight_suit_rack.webp',
    sha256: '1d589472bf6ab48aebb45fb64147d57907a4ae576e0908fdef06f97019981a72',
    capturedDaysAgo: 12,
  ),
  _attachment(
    idSeed: 'demo-media-scrubber-cartridge-rack',
    taskSeed: 'task-air-scrubbers',
    fileName: 'scrubber_cartridge_rack.webp',
    sha256: 'b772746087c4f844f0ff61f89d726893a9f4baa34f532965f764fecde4b1133e',
    capturedDaysAgo: 2,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-co2-sensor-panel',
    taskSeed: 'task-air-scrubbers',
    fileName: 'co2_sensor_panel.webp',
    sha256: '704fcc2269963afdc22a7f063b0fa62b13674f901b60e272fe65718305ee8a21',
    capturedDaysAgo: 2,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-orbital-ice-resurfacer',
    taskSeed: 'task-ice-rink-resurface',
    fileName: 'orbital_ice_resurfacer.webp',
    sha256: '6b75acb45e81ddba9386925f616b2e316e3ae2d47a611af6b2d97206fe713328',
    capturedDaysAgo: 15,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-rink-groove-closeup',
    taskSeed: 'task-ice-rink-resurface',
    fileName: 'rink_groove_closeup.webp',
    sha256: '68ca22ca1f3600936e2234e524aad5362f93b1a54ae2a719da69ad34828deb55',
    capturedDaysAgo: 15,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-array-tilt-sensor',
    taskSeed: 'task-solar-array-tilt',
    fileName: 'array_tilt_sensor.webp',
    sha256: '23b3c7ada80f2e0b3cf3bf16cb552371a0cf21dc46ce851573a7091afc665915',
    capturedDaysAgo: 6,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-solar-array-spacewalk',
    taskSeed: 'task-solar-array-tilt',
    fileName: 'solar_array_spacewalk.webp',
    sha256: '9e7667f2461510cec79349ecfaff1b5298ed00aa95d9c930b796338231e55915',
    capturedDaysAgo: 6,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-recycler-filter-feathers',
    taskSeed: 'task-water-recycler',
    fileName: 'recycler_filter_feathers.webp',
    sha256: '27912e83291d7e6cd3147a583700f57628b508e8b356b3222634d016fe86d998',
    capturedDaysAgo: 6,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-recycler-throughput-panel',
    taskSeed: 'task-water-recycler',
    fileName: 'recycler_throughput_panel.webp',
    sha256: 'a6b1d445fad6bb366e35fe39b6f4912b80d2ba7d504388105c3b1a175110c0b7',
    capturedDaysAgo: 5,
    categoryId: _habitatEngineering,
  ),
  _attachment(
    idSeed: 'demo-media-krill-supplier-samples',
    taskSeed: 'task-krill-supplier',
    fileName: 'krill_supplier_samples.webp',
    sha256: 'f8d9385c1c9c1e6e8802b245e860c77820cdca72fe51f80dcdbc70623b86813f',
    capturedDaysAgo: 7,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-europa-krill-quote',
    taskSeed: 'task-krill-supplier',
    fileName: 'europa_krill_quote.webp',
    sha256: 'ae310f1a63baa3baf9b43485567a1e2a49772615c6b98588c9b5d370cb117f82',
    capturedDaysAgo: 7,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-dock-pod-count-photo',
    taskSeed: 'task-shuttle-manifest',
    fileName: 'dock_pod_count_photo.webp',
    sha256: '4d81f30f8655c0f5888c419ff51e431f8bbc01075cdcc2fa66dfaaf434952a26',
    capturedDaysAgo: 1,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-manifest-discrepancy-board',
    taskSeed: 'task-shuttle-manifest',
    fileName: 'manifest_discrepancy_board.webp',
    sha256: '5f3c78be4b7f3bd5036b044219cd68c837baacae028cd74a8954fd87831db41a',
    capturedDaysAgo: 1,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-pod-seal-certificate',
    taskSeed: 'task-pod-seal-order',
    fileName: 'pod_seal_certificate.webp',
    sha256: '6755495883c38e576e674bc0e775caa2757b87172f032d5a0ecf6fd301011df0',
    capturedDaysAgo: 10,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-replacement-seal-samples',
    taskSeed: 'task-pod-seal-order',
    fileName: 'replacement_seal_samples.webp',
    sha256: 'fc176697bb54fe0f2e297d80db657630818ce560525990af6e5bfaec6d75d35e',
    capturedDaysAgo: 10,
    categoryId: _logisticsSupply,
  ),
  _attachment(
    idSeed: 'demo-media-chick-daycare-rota',
    taskSeed: 'task-chick-daycare',
    fileName: 'chick_daycare_rota.webp',
    sha256: 'd2fd18e85fa322e88f0c7af93358aaec0921eb713983a8f80ac959c322904dbf',
    capturedDaysAgo: 16,
  ),
  _attachment(
    idSeed: 'demo-media-daycare-laundry-hideout',
    taskSeed: 'task-chick-daycare',
    fileName: 'daycare_laundry_hideout.webp',
    sha256: '3e9e0770ab14589f5197fad14d9b74210bd33153f90e7555cde5fcc71de41cdf',
    capturedDaysAgo: 16,
  ),
  _attachment(
    idSeed: 'demo-media-colony-movie-ballot',
    taskSeed: 'task-movie-night',
    fileName: 'colony_movie_ballot.webp',
    sha256: '5976a5e25216316c69a5d0a518c9a73cb82b6aec03f80dda1e7f69ca5d98ae8e',
    capturedDaysAgo: 18,
  ),
  _attachment(
    idSeed: 'demo-media-ice-documentary-dome',
    taskSeed: 'task-movie-night',
    fileName: 'ice_documentary_dome.webp',
    sha256: 'a47aa219c65e6bbf8d376ed8f3b0f6cffb3dc918d88f3fb69d6ac2bea3b96acf',
    capturedDaysAgo: 18,
  ),
]);

/// The sole cover belonging to [taskId].
DemoMediaAsset demoMediaCoverForTask(String taskId) => demoMediaAssets
    .singleWhere((asset) => asset.taskId == taskId && asset.isCover);

/// All catalog images belonging to [taskId], cover first.
Iterable<DemoMediaAsset> demoMediaForTask(String taskId) =>
    demoMediaAssets.where((asset) => asset.taskId == taskId);
