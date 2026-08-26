/// Semantic icon tokens: the app's entire icon vocabulary, in one place.
///
/// Hand-authored, for the same reason as `motion_tokens.dart` and
/// `sizing_tokens.dart`: icons are brightness-invariant (nothing lerps) and are
/// not a Figma *variable* in this repo's export, so there is no upstream source
/// to generate from. A named `const` set is the honest representation.
///
/// ## Why a token layer at all
///
/// Before this existed, 1,741 call sites across 449 files each picked their own
/// glyph straight from Material. That meant the same idea wore different faces
/// depending on who wrote the widget — `close` / `clear` / `cancel` for one
/// dismiss, four spellings of a tick for one confirmation — and it meant that
/// changing icon set was a 449-file edit. Naming the *intent* instead of the
/// glyph collapses those synonyms and makes the binding below the only place
/// the app commits to an icon family.
///
/// ## How to use it
///
/// Pick by what the icon *means*, never by what it looks like. Two tokens may
/// resolve to the same Lucide glyph today (`expand` and `chevronDown`); they
/// are separate because they answer to different intents and either may be
/// retuned without disturbing the other. Reaching past this class to
/// `LucideIcons` directly in feature code defeats the point, and
/// `make icon_check` fails the build on it.
///
/// If no token fits, add one here with a doc comment saying what it means —
/// do not inline a glyph at the call site.
///
/// ## Domain pictograms are not here
///
/// This class is the *UI vocabulary*: actions, status, navigation, structure.
/// Icons that stand for a domain value the user picked — a category's glyph, an
/// entry type, a health data kind — live in their own enum-to-glyph maps
/// (`category_icon_data.dart` and friends) and are allow-listed by the guard.
/// Folding several hundred one-off pictograms in here would make the vocabulary
/// unsearchable and would not make it more consistent.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The app's semantic icon set, bound to Lucide's outlined family.
abstract final class LottiIcons {
  // ── Selection & confirmation ────────────────────────────────────────────────

  /// A bare affirmative tick: applied state, 'saved', a chosen row.
  static const IconData confirm = LucideIcons.check;

  /// Success carried in its own badge — a completed item, a passed check.
  static const IconData confirmCircled = LucideIcons.circleCheck;

  /// A ticked checkbox.
  static const IconData checkboxChecked = LucideIcons.squareCheck;

  /// An empty checkbox.
  static const IconData checkboxUnchecked = LucideIcons.square;

  /// The chosen option in a radio group.
  static const IconData radioSelected = LucideIcons.circleDot;

  /// An unchosen radio option, and the generic small dot marker.
  static const IconData radioUnselected = LucideIcons.circle;

  /// A checklist, or 'mark everything done'.
  static const IconData checkAll = LucideIcons.listChecks;

  // ── Primary actions ─────────────────────────────────────────────────────────

  /// Create or append.
  static const IconData add = LucideIcons.plus;

  /// Create, where the affordance needs its own weight.
  static const IconData addCircled = LucideIcons.circlePlus;

  /// Detach or decrement — never destructive.
  static const IconData remove = LucideIcons.minus;

  /// Detach, where the affordance needs its own weight.
  static const IconData removeCircled = LucideIcons.circleMinus;

  /// Dismiss a sheet, clear a field, drop a chip.
  static const IconData close = LucideIcons.x;

  /// Cancel an in-flight thing, as opposed to dismissing a surface.
  static const IconData closeCircled = LucideIcons.circleX;

  /// Move to trash — reversible.
  static const IconData delete = LucideIcons.trash2;

  /// Irreversible destruction. Deliberately the barer can.
  static const IconData deleteForever = LucideIcons.trash;

  /// Enter edit mode on an existing thing.
  static const IconData edit = LucideIcons.pencil;

  /// Edit prose specifically — a note, a comment, a review.
  static const IconData editNote = LucideIcons.squarePen;

  /// Commit pending changes.
  static const IconData save = LucideIcons.save;

  /// Copy to clipboard.
  static const IconData copy = LucideIcons.copy;

  /// Revert the last step.
  static const IconData undo = LucideIcons.undo2;

  /// Bring back a previous state, or show what came before.
  static const IconData restore = LucideIcons.history;

  /// Re-fetch. Also the spinner glyph while a refresh runs.
  static const IconData refresh = LucideIcons.refreshCw;

  /// Run the same thing again from the start.
  static const IconData replay = LucideIcons.rotateCcw;

  /// Dispatch a message or prompt.
  static const IconData send = LucideIcons.send;

  /// Search or find.
  static const IconData search = LucideIcons.search;

  /// Search within or interpret an image.
  static const IconData searchImage = LucideIcons.imagePlay;

  /// Narrow a list by criteria.
  static const IconData filter = LucideIcons.listFilter;

  /// Reorder a list.
  static const IconData sort = LucideIcons.arrowUpDown;

  /// Adjust parameters — sliders, not app settings.
  static const IconData tune = LucideIcons.settings2;

  /// Application or feature settings.
  static const IconData settings = LucideIcons.settings;

  /// Pull something down to the device.
  static const IconData download = LucideIcons.download;

  /// Push a local file outward.
  static const IconData upload = LucideIcons.upload;

  /// Leave the app — opens a browser or another application.
  static const IconData openExternal = LucideIcons.externalLink;

  /// A link between two entities.
  static const IconData link = LucideIcons.link;

  /// A severed link.
  static const IconData linkOff = LucideIcons.unlink;

  /// The drag handle on a reorderable row.
  static const IconData drag = LucideIcons.gripVertical;

  /// Overflow menu, inline in a row.
  static const IconData more = LucideIcons.ellipsis;

  /// Overflow menu, anchored to a row's trailing edge.
  static const IconData moreVertical = LucideIcons.ellipsisVertical;

  /// Move out of the active set without deleting.
  static const IconData archive = LucideIcons.archive;

  /// Return an archived item to the active set.
  static const IconData unarchive = LucideIcons.archiveRestore;

  /// Forbidden or unavailable — not merely disabled.
  static const IconData block = LucideIcons.ban;

  /// Apply an automatic fix or transformation.
  static const IconData magic = LucideIcons.wandSparkles;

  /// Randomise order.
  static const IconData shuffle = LucideIcons.shuffle;

  /// A recurring thing.
  static const IconData repeat = LucideIcons.repeat;

  /// Centre on, or target, a specific thing.
  static const IconData focus = LucideIcons.crosshair;

  /// A direct-manipulation affordance.
  static const IconData touch = LucideIcons.pointer;

  /// Scan or present a QR code.
  static const IconData scanQr = LucideIcons.qrCode;

  // ── Navigation ──────────────────────────────────────────────────────────────

  /// Return to the previous screen.
  static const IconData back = LucideIcons.arrowLeft;

  /// Advance to the next screen or step.
  static const IconData forward = LucideIcons.arrowRight;

  /// Step back within a set — a previous day, a previous page.
  static const IconData chevronLeft = LucideIcons.chevronLeft;

  /// Step forward within a set, or 'this row opens'.
  static const IconData chevronRight = LucideIcons.chevronRight;

  /// Scroll or page upward.
  static const IconData chevronUp = LucideIcons.chevronUp;

  /// Scroll or page downward; the closed state of a dropdown.
  static const IconData chevronDown = LucideIcons.chevronDown;

  /// Reveal a collapsed section. Same glyph as chevronDown, different intent —
  /// keep them separate so either can be retuned alone.
  static const IconData expand = LucideIcons.chevronDown;

  /// Hide an expanded section.
  static const IconData collapse = LucideIcons.chevronUp;

  /// A collapsed control that opens in both directions — a picker.
  static const IconData expandBoth = LucideIcons.chevronsUpDown;

  /// Directional movement or an upward delta.
  static const IconData arrowUp = LucideIcons.arrowUp;

  /// Directional movement or a downward delta.
  static const IconData arrowDown = LucideIcons.arrowDown;

  /// The return/submit key, or a nested continuation.
  static const IconData returnKey = LucideIcons.cornerDownLeft;

  /// Two things set against each other.
  static const IconData compare = LucideIcons.arrowLeftRight;

  /// Show or hide the side panel.
  static const IconData sidebar = LucideIcons.panelLeft;

  /// A plain list view.
  static const IconData list = LucideIcons.list;

  /// The multi-panel overview view.
  static const IconData dashboard = LucideIcons.layoutDashboard;

  /// A hierarchy or dependency graph.
  static const IconData tree = LucideIcons.network;

  /// A connected set of entities — the knowledge graph of a task's links.
  ///
  /// `waypoints` (two nodes joined by a routed path) rather than Lucide's
  /// `workflow` or Material's `hub`: the relationships this opens are peer
  /// links between tasks, so a glyph implying a pipeline or a central hub with
  /// spokes states the wrong shape. `hub_outlined` also put thirteen elements
  /// into a 26pt app-bar slot and read as noise at that size.
  static const IconData hub = LucideIcons.waypoints;

  // ── Status ──────────────────────────────────────────────────────────────────

  /// A failure the user must resolve.
  static const IconData error = LucideIcons.circleAlert;

  /// A caution — the thing works, but not as intended.
  static const IconData warning = LucideIcons.triangleAlert;

  /// Explanatory detail, never a problem.
  static const IconData info = LucideIcons.info;

  /// Documentation or a hint.
  static const IconData help = LucideIcons.circleHelp;

  /// A suggestion the user may act on.
  static const IconData tip = LucideIcons.lightbulb;

  /// Waiting on something out of the user's hands.
  static const IconData pending = LucideIcons.hourglass;

  /// Newly available, or independently verified.
  static const IconData verified = LucideIcons.badgeCheck;

  /// A defect report or debug affordance.
  static const IconData bug = LucideIcons.bug;

  /// Marked for attention.
  static const IconData flag = LucideIcons.flag;

  /// Starred or rated.
  static const IconData star = LucideIcons.star;

  /// A favourite, or an affective 'liked' state.
  static const IconData favorite = LucideIcons.heart;

  /// Saved for later.
  static const IconData bookmark = LucideIcons.bookmark;

  /// A completed milestone worth marking.
  static const IconData celebrate = LucideIcons.partyPopper;

  /// A launch, or a big step forward.
  static const IconData rocket = LucideIcons.rocket;

  /// An unbroken run.
  static const IconData streak = LucideIcons.flame;

  /// Speed, energy, or an instant action.
  static const IconData bolt = LucideIcons.zap;

  // ── Time ────────────────────────────────────────────────────────────────────

  /// A point in time.
  static const IconData schedule = LucideIcons.clock;

  /// Elapsed or remaining duration.
  static const IconData timer = LucideIcons.timer;

  /// The current day in a calendar.
  static const IconData today = LucideIcons.calendarDays;

  /// A dated entity.
  static const IconData calendar = LucideIcons.calendar;

  /// Adjust a schedule.
  static const IconData calendarEdit = LucideIcons.calendarCog;

  /// Defer a reminder.
  static const IconData snooze = LucideIcons.alarmClockOff;

  /// Progress through a fixed span.
  static const IconData timelapse = LucideIcons.timer;

  /// Events laid out along time.
  static const IconData timeline = LucideIcons.chartNoAxesGantt;

  /// Night, sleep, or a dark-hours context.
  static const IconData night = LucideIcons.moon;

  /// Daytime or a morning context.
  static const IconData day = LucideIcons.sun;

  // ── AI ──────────────────────────────────────────────────────────────────────

  /// AI-generated or AI-assisted. The app's single AI marker.
  static const IconData aiSpark = LucideIcons.sparkles;

  /// A stack of AI results or variants.
  static const IconData aiStack = LucideIcons.layers;

  /// A model or agent as an actor.
  static const IconData aiModel = LucideIcons.bot;

  /// Reasoning, inference, or a thinking step.
  static const IconData reasoning = LucideIcons.brain;

  /// Experimental — behind a flag or in evaluation.
  static const IconData science = LucideIcons.flaskConical;

  /// Speech turned into text.
  static const IconData transcribe = LucideIcons.captions;

  /// A condensed restatement.
  static const IconData summarize = LucideIcons.textQuote;

  // ── Media & capture ─────────────────────────────────────────────────────────

  /// Recording, or the affordance that starts it.
  static const IconData mic = LucideIcons.mic;

  /// Recording available but not running.
  static const IconData micIdle = LucideIcons.micOff;

  /// Start playback.
  static const IconData play = LucideIcons.play;

  /// Start playback, where the control stands alone.
  static const IconData playCircled = LucideIcons.circlePlay;

  /// Suspend playback.
  static const IconData pause = LucideIcons.pause;

  /// Suspend playback, where the control stands alone.
  static const IconData pauseCircled = LucideIcons.circlePause;

  /// End playback or recording outright.
  static const IconData stop = LucideIcons.square;

  /// Audio output level.
  static const IconData volume = LucideIcons.volume2;

  /// An audio signal.
  static const IconData waveform = LucideIcons.audioWaveform;

  /// A single picture.
  static const IconData image = LucideIcons.image;

  /// A picture that failed to load.
  static const IconData imageBroken = LucideIcons.imageOff;

  /// A collection of pictures.
  static const IconData photoLibrary = LucideIcons.images;

  /// Attach a new picture.
  static const IconData addPhoto = LucideIcons.imagePlus;

  /// Moving footage.
  static const IconData video = LucideIcons.video;

  /// A spoken contribution attributed to a person.
  static const IconData voice = LucideIcons.audioLines;

  // ── Content ─────────────────────────────────────────────────────────────────

  /// A written entry.
  static const IconData note = LucideIcons.notebookPen;

  /// A document or its body text.
  static const IconData description = LucideIcons.fileText;

  /// Reading, or a long-form reference.
  static const IconData book = LucideIcons.book;

  /// A container of entries.
  static const IconData folder = LucideIcons.folder;

  /// The container currently being looked into.
  static const IconData folderOpen = LucideIcons.folderOpen;

  /// Unsorted incoming items.
  static const IconData inbox = LucideIcons.inbox;

  /// A tag applied to an entry.
  static const IconData label = LucideIcons.tag;

  /// The category an entry belongs to.
  static const IconData category = LucideIcons.shapes;

  /// Text formatting or a text field.
  static const IconData text = LucideIcons.type;

  /// Source code or a raw payload.
  static const IconData code = LucideIcons.code;

  /// A conversation.
  static const IconData chat = LucideIcons.messageCircle;

  /// A multi-party discussion.
  static const IconData forum = LucideIcons.messagesSquare;

  /// Email.
  static const IconData mail = LucideIcons.mail;

  /// A phone call.
  static const IconData call = LucideIcons.phone;

  /// Colour or theming.
  static const IconData palette = LucideIcons.palette;

  /// Freehand or styling input.
  static const IconData brush = LucideIcons.brush;

  /// Motion or an animated preview.
  static const IconData animation = LucideIcons.clapperboard;

  /// Locale or translation.
  static const IconData language = LucideIcons.languages;

  /// A light-footprint or low-cost option.
  static const IconData eco = LucideIcons.leaf;

  // ── People ──────────────────────────────────────────────────────────────────

  /// A single individual.
  static const IconData person = LucideIcons.user;

  /// A group of individuals.
  static const IconData people = LucideIcons.users;

  /// Invite or add someone.
  static const IconData personAdd = LucideIcons.userPlus;

  /// Pull people in from the device's address book.
  ///
  /// Distinct from [personAdd] on purpose: these are two different actions on
  /// the same screen, and Material told them apart as `person_add_rounded` and
  /// `group_add_rounded`. Both map to one Lucide glyph, so the import action
  /// takes the address book instead.
  static const IconData contactImport = LucideIcons.bookUser;

  // ── Security & visibility ───────────────────────────────────────────────────

  /// Encrypted, private, or requiring authentication.
  static const IconData lock = LucideIcons.lock;

  /// A privacy or safety guarantee.
  static const IconData shield = LucideIcons.shield;

  /// Currently shown.
  static const IconData visible = LucideIcons.eye;

  /// Currently hidden.
  static const IconData hidden = LucideIcons.eyeOff;

  // ── Connectivity & sync ─────────────────────────────────────────────────────

  /// Two-way replication between devices.
  static const IconData sync = LucideIcons.refreshCcw;

  /// Replication is stuck or failing.
  static const IconData syncProblem = LucideIcons.refreshCwOff;

  /// A remote service.
  static const IconData cloud = LucideIcons.cloud;

  /// A remote service that is unreachable.
  static const IconData cloudOff = LucideIcons.cloudOff;

  /// Connection strength.
  static const IconData signal = LucideIcons.signal;

  /// Notifications, at rest.
  static const IconData notification = LucideIcons.bell;

  /// A notification demanding attention now.
  static const IconData notificationActive = LucideIcons.bellRing;

  // ── Devices ─────────────────────────────────────────────────────────────────

  /// A desktop machine.
  static const IconData computer = LucideIcons.monitor;

  /// A laptop.
  static const IconData laptop = LucideIcons.laptop;

  /// A phone.
  static const IconData phone = LucideIcons.smartphone;

  /// The device roster as a whole.
  static const IconData devices = LucideIcons.monitorSmartphone;

  /// Compute or hardware capability.
  static const IconData memory = LucideIcons.cpu;

  /// Maintenance or a repair action.
  static const IconData build = LucideIcons.wrench;

  // ── Data & measurement ──────────────────────────────────────────────────────

  /// Quantities compared across categories.
  static const IconData chart = LucideIcons.chartColumn;

  /// A trend read over time.
  static const IconData insights = LucideIcons.chartLine;

  /// An improving measure.
  static const IconData trendingUp = LucideIcons.trendingUp;

  /// Rate or performance.
  static const IconData speed = LucideIcons.gauge;

  /// A measured length or amount.
  static const IconData measure = LucideIcons.ruler;

  /// A vital sign.
  static const IconData heartRate = LucideIcons.heartPulse;

  /// Steps or walking activity.
  static const IconData walk = LucideIcons.footprints;

  /// Deliberate exercise.
  static const IconData fitness = LucideIcons.dumbbell;

  /// The home surface.
  static const IconData home = LucideIcons.house;

  /// Work context.
  static const IconData work = LucideIcons.briefcase;

  /// A place.
  static const IconData location = LucideIcons.mapPin;

  /// A geographic view.
  static const IconData map = LucideIcons.map;

  // ── Views & layout ──────────────────────────────────────────────────────────

  /// Lay the plan out as stacked rows — one day at a time.
  static const IconData viewRows = LucideIcons.rows3;

  /// Lay the plan out side by side — a week at a glance.
  static const IconData viewColumns = LucideIcons.columns3;

  /// Lay items out as a swipeable gallery.
  static const IconData viewCarousel = LucideIcons.galleryHorizontal;

  /// Rearrange what the overview shows.
  static const IconData dashboardEdit = LucideIcons.layoutGrid;

  /// Stacked planes — overlays on a map or chart.
  static const IconData layers = LucideIcons.layers;

  /// Grow to fill the available space.
  static const IconData expandFull = LucideIcons.maximize2;

  /// Reposition freely in two dimensions.
  static const IconData move = LucideIcons.move;

  /// A repeating background or grid.
  static const IconData pattern = LucideIcons.grid3x3;

  /// A horizontal rule between blocks.
  static const IconData divider = LucideIcons.minus;

  // ── Extended actions ────────────────────────────────────────────────────────

  /// Append an item to a checklist.
  static const IconData addTask = LucideIcons.listPlus;

  /// Empty a list in one action.
  static const IconData clearAll = LucideIcons.listX;

  /// Two branches becoming one.
  static const IconData merge = LucideIcons.merge;

  /// One branch becoming two.
  static const IconData split = LucideIcons.split;

  /// Send outward to another app or person.
  static const IconData share = LucideIcons.share;

  /// Pull down from a remote service.
  static const IconData cloudDownload = LucideIcons.cloudDownload;

  /// Read text out of a document or photo.
  static const IconData scanDocument = LucideIcons.scanText;

  /// Search within a document's contents.
  static const IconData manageSearch = LucideIcons.fileSearch;

  /// A search that found nothing.
  static const IconData searchOff = LucideIcons.searchX;

  /// Look someone up.
  static const IconData findPerson = LucideIcons.userSearch;

  /// An endorsement.
  static const IconData recommend = LucideIcons.thumbsUp;

  /// Send to the bottom of the queue.
  static const IconData lowPriority = LucideIcons.arrowDownToLine;

  /// A numbered position in a sequence.
  static const IconData stepNumber = LucideIcons.listOrdered;

  /// Advance, where the control stands alone.
  static const IconData forwardCircled = LucideIcons.circleArrowRight;

  /// Jump to the end, past several items at once.
  static const IconData chevronsDown = LucideIcons.chevronsDown;

  /// Jump to the start, past several items at once.
  static const IconData chevronsUp = LucideIcons.chevronsUp;

  /// Close a control that opens in both directions.
  static const IconData collapseBoth = LucideIcons.chevronsDownUp;

  /// The main navigation drawer.
  static const IconData menu = LucideIcons.menu;

  // ── Extended status & time ──────────────────────────────────────────────────

  /// A reminder that will sound at a set time.
  static const IconData alarm = LucideIcons.alarmClock;

  /// Everything in a set is done, not just one thing.
  static const IconData confirmAll = LucideIcons.checkCheck;

  /// A date that is settled.
  static const IconData eventConfirmed = LucideIcons.calendarCheck;

  /// A checked-off review.
  static const IconData factCheck = LucideIcons.clipboardCheck;

  /// A dated thing with a time of day.
  static const IconData calendarTime = LucideIcons.calendarClock;

  /// Dawn or dusk — the shoulder of the day.
  static const IconData twilight = LucideIcons.sunrise;

  // ── Extended media & content ────────────────────────────────────────────────

  /// A stored recording.
  static const IconData audioFile = LucideIcons.fileAudio;

  /// Capture is unavailable or disallowed.
  static const IconData cameraOff = LucideIcons.cameraOff;

  /// Capture what is on screen.
  static const IconData screenshot = LucideIcons.monitorDot;

  /// A blurred or obscured region.
  static const IconData blur = LucideIcons.aperture;

  /// A captured snapshot of values.
  static const IconData clipboard = LucideIcons.clipboard;

  /// A captured list of values.
  static const IconData clipboardText = LucideIcons.clipboardList;

  /// A computed aggregate.
  static const IconData formula = LucideIcons.sigma;

  /// A premium or standout item.
  static const IconData gem = LucideIcons.gem;

  /// A legal or policy matter.
  static const IconData legal = LucideIcons.gavel;

  /// A path through several stops.
  static const IconData route = LucideIcons.route;

  // ── People, security & mood ─────────────────────────────────────────────────

  /// An individual, where the avatar slot needs a filled shape.
  static const IconData personCircled = LucideIcons.circleUser;

  /// A person's details as a record.
  static const IconData contactCard = LucideIcons.contact;

  /// An identity or credential.
  static const IconData idBadge = LucideIcons.idCard;

  /// A credential or API key.
  static const IconData key = LucideIcons.key;

  /// Keyboard input or a shortcut.
  static const IconData keyboard = LucideIcons.keyboard;

  /// Decrypted, or no longer requiring authentication.
  static const IconData unlocked = LucideIcons.lockOpen;

  /// Leave the account.
  static const IconData signOut = LucideIcons.logOut;

  /// Biometric authentication.
  static const IconData fingerprint = LucideIcons.fingerprint;

  /// A welcome or a first-run greeting.
  static const IconData greeting = LucideIcons.hand;

  /// A neutral mood rating.
  static const IconData moodNeutral = LucideIcons.meh;

  /// A positive mood rating.
  static const IconData moodGood = LucideIcons.smile;

  /// The assistant as a conversational partner.
  static const IconData assistant = LucideIcons.botMessageSquare;

  /// A text message.
  static const IconData sms = LucideIcons.messageSquare;

  // ── Devices, connectivity & health ──────────────────────────────────────────

  /// Device charge level.
  static const IconData battery = LucideIcons.batteryFull;

  /// A machine that is unreachable.
  static const IconData computerOff = LucideIcons.monitorOff;

  /// A wireless connection.
  static const IconData wifi = LucideIcons.wifi;

  /// No wireless connection.
  static const IconData wifiOff = LucideIcons.wifiOff;

  /// Contrast, or a light/dark preference.
  static const IconData contrast = LucideIcons.contrast;

  /// Air quality or a breathing exercise.
  static const IconData air = LucideIcons.wind;

  /// Audio input or a hearing-related measure.
  static const IconData hearing = LucideIcons.ear;

  /// A recorded body weight.
  static const IconData weight = LucideIcons.scale;

  /// Health and safety data.
  static const IconData healthShield = LucideIcons.shieldPlus;

  /// A clinical measurement.
  static const IconData stethoscope = LucideIcons.stethoscope;

  /// Cycling activity.
  static const IconData cycling = LucideIcons.bike;

  /// Running activity.
  static const IconData running = LucideIcons.personStanding;

  /// Swimming activity.
  static const IconData swimming = LucideIcons.waves;

  /// A declining measure.
  static const IconData trendingDown = LucideIcons.trendingDown;
}
