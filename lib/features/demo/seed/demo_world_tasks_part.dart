part of 'demo_world.dart';

/// The expansion clusters of the penguin world: launch readiness, habitat
/// maintenance, logistics and colony life, built with the factory's helpers.
List<Task> _penguinExpansionTasks({
  required DemoSeedText t,
  required DemoDates dates,
  required _TaskBuilder task,
  required _NoteBuilder note,
  required _StatusAt openAt,
  required _StatusAt groomedAt,
  required _StatusAt runningAt,
  required _StatusAt doneAt,
}) {
  return <Task>[
    // --- Cluster 1: launch readiness -----------------------------------
    task(
      id: demoLaunchCommsTaskId,
      title: t('Draft the launch comms plan', 'Kommunikationsplan entwerfen'),
      description: t(
        'Agree who announces what on launch day, and in which order. '
            'Mission Control wants one voice on the public feed, the colony '
            'wants updates in plain penguin, and the sponsors expect their '
            'logo mentioned exactly twice. Draft the running order, name a '
            'speaker per slot, and get sign-off from Flight Direction '
            'before the rehearsal.',
        'Klärt, wer am Starttag was verkündet — und in welcher Reihenfolge. '
            'Mission Control will eine Stimme auf dem öffentlichen Kanal, '
            'die Kolonie will Updates in klarem Pinguinisch, und die '
            'Sponsoren erwarten ihr Logo genau zweimal. Entwerft den '
            'Ablaufplan, benennt pro Slot eine Stimme und holt vor der '
            'Probe das Okay der Flugleitung ein.',
      ),
      status: openAt('launch-comms', 9),
      priority: TaskPriority.p2Medium,
      due: dates.tomorrow(9),
      coverArtId: demoMediaCoverForTask(demoLaunchCommsTaskId).id,
      labelIds: const [manualDemoProjectLabelId],
      estimate: const Duration(minutes: 45),
      createdAt: dates.daysAgo(9),
      dateFrom: dates.daysAgo(9),
    ),
    task(
      id: demoIcePadWeatherTaskId,
      title: t(
        'Check the ice-pad weather window',
        'Wetterfenster am Eisstartplatz prüfen',
      ),
      description: t(
        'Confirm the crosswind stays under limits for the launch slot. The '
            'ice pad tolerates 18 knots across the strip and the forecast '
            'has been flirting with 20 all week. Pull the morning '
            'soundings, compare the three forecast models, and give Flight '
            'Direction a clear go or no-go with a confidence note by 15:00.',
        'Bestätigt, dass der Seitenwind im Startfenster unter dem Limit '
            'bleibt. Der Eisstartplatz verträgt 18 Knoten quer zur Bahn, '
            'und die Vorhersage kokettiert die ganze Woche mit 20. Zieht '
            'die Morgensondierungen, vergleicht die drei Wettermodelle und '
            'gebt der Flugleitung bis 15:00 ein klares Go oder No-Go samt '
            'Konfidenznotiz.',
      ),
      status: runningAt('ice-pad-weather', 2),
      priority: TaskPriority.p1High,
      due: dates.today(17),
      coverArtId: demoMediaCoverForTask(demoIcePadWeatherTaskId).id,
      labelIds: const [manualDemoProjectLabelId, demoResearchLabelId],
      estimate: const Duration(minutes: 30),
      createdAt: dates.daysAgo(11),
      dateFrom: dates.daysAgo(2),
    ),
    task(
      id: demoColdChainAuditTaskId,
      title: t(
        'Audit the cold-chain freezer logs',
        'Kühlketten-Protokolle prüfen',
      ),
      description: t(
        'Find every gap in the freezer logs before the sardines ship. '
            'Freezer 3 dropped out of range twice last month, and customs '
            'wants an unbroken cold-chain record for every pod on the '
            'manifest. Export the logs, flag every excursion with its '
            'duration, and sign the audit so the shipment can clear.',
        'Findet jede Lücke in den Kühlprotokollen, bevor die Sardinen '
            'verschifft werden. Kühler 3 ist letzten Monat zweimal aus dem '
            'Sollbereich gefallen, und der Zoll verlangt eine lückenlose '
            'Kühlkette für jede Kapsel auf der Frachtliste. Exportiert die '
            'Protokolle, markiert jede Abweichung samt Dauer und zeichnet '
            'die Prüfung ab, damit die Ladung freikommt.',
      ),
      status: doneAt('cold-chain-audit', 1),
      priority: TaskPriority.p2Medium,
      due: dates.inDays(2, 12),
      coverArtId: demoMediaCoverForTask(demoColdChainAuditTaskId).id,
      labelIds: const [manualDemoProjectLabelId],
      estimate: const Duration(hours: 2),
      createdAt: dates.daysAgo(30),
      dateFrom: dates.daysAgo(6),
      checklistIds: [demoFreezerChecklistId],
    ),
    task(
      id: demoLaunchRehearsalTaskId,
      title: t('Run the launch-day rehearsal', 'Startprobe durchführen'),
      description: t(
        'Walk the whole launch morning once, at full speed, with the crew. '
            'Every handoff gets timed, every call gets spoken out loud, and '
            'nobody pauses to explain — that is what the debrief is for. '
            'Reserve the pad for three hours and rehearse the abort call '
            'until it sounds boring.',
        'Geht den ganzen Startmorgen einmal in Echtzeit mit der Crew '
            'durch. Jede Übergabe wird gestoppt, jeder Funkspruch laut '
            'gesprochen, und niemand hält an, um etwas zu erklären — dafür '
            'ist die Nachbesprechung da. Reserviert den Startplatz für '
            'drei Stunden und probt den Abbruchruf, bis er langweilig '
            'klingt.',
      ),
      status: groomedAt('launch-rehearsal', 4),
      priority: TaskPriority.p1High,
      due: dates.inDays(3, 9),
      coverArtId: demoMediaCoverForTask(demoLaunchRehearsalTaskId).id,
      labelIds: const [manualDemoProjectLabelId],
      estimate: const Duration(hours: 3),
      createdAt: dates.daysAgo(13),
      dateFrom: dates.daysAgo(4),
      checklistIds: [demoRehearsalChecklistId],
    ),
    task(
      id: demoFlightSuitTaskId,
      title: t('Fit the penguin flight suits', 'Pinguin-Fluganzüge anpassen'),
      description: t(
        'Measure every flyer and send the three wide-flipper suits back. '
            'The supplier mixed up the flipper gauges, so half the squad '
            'is wearing suits that whistle above Mach 0.2. Remeasure all '
            'twelve flyers, tag the returns, and confirm the replacement '
            'delivery lands before the rehearsal.',
        'Vermesst jeden Flieger und schickt die drei Anzüge mit weiten '
            'Flossen zurück. Der Lieferant hat die Flossenmaße vertauscht, '
            'deshalb pfeift bei der halben Staffel der Anzug ab Mach 0,2. '
            'Vermesst alle zwölf Flieger neu, kennzeichnet die '
            'Rücksendungen und bestätigt, dass der Ersatz vor der Probe '
            'eintrifft.',
      ),
      status: openAt('flight-suit', 12),
      priority: TaskPriority.p3Low,
      due: dates.nextMonday(9),
      coverArtId: demoMediaCoverForTask(demoFlightSuitTaskId).id,
      labelIds: const [manualDemoProjectLabelId, demoWaitingLabelId],
      estimate: const Duration(hours: 1, minutes: 30),
      createdAt: dates.daysAgo(12),
      dateFrom: dates.daysAgo(12),
    ),
    // --- Cluster 2: habitat engineering --------------------------------
    task(
      id: demoAirScrubbersTaskId,
      title: t(
        'Replace the air scrubber cartridges',
        'Filterpatronen der Luftreinigung tauschen',
      ),
      description: t(
        'Swap all four cartridges in Bay A before the CO2 alarm gets '
            'bored. The current set is 12 percent over its rated hours and '
            'the alarm has started clearing its throat at night. Vent the '
            'bay first, swap A1 through A4 in order, and log the new CO2 '
            'baseline so Habitat Engineering can close the maintenance '
            'ticket.',
        'Tauscht alle vier Patronen in Bucht A, bevor dem CO2-Alarm '
            'langweilig wird. Der aktuelle Satz liegt 12 Prozent über '
            'seinen Soll-Stunden, und der Alarm räuspert sich nachts '
            'schon. Entlüftet zuerst die Bucht, tauscht A1 bis A4 der '
            'Reihe nach und notiert den neuen CO2-Ausgangswert, damit die '
            'Habitat-Technik das Wartungsticket schließen kann.',
      ),
      status: runningAt('air-scrubbers', 2),
      priority: TaskPriority.p0Urgent,
      due: dates.today(17),
      coverArtId: demoMediaCoverForTask(demoAirScrubbersTaskId).id,
      labelIds: const [manualDemoCriticalLabelId],
      estimate: const Duration(hours: 2),
      categoryId: demoHabitatCategoryId,
      createdAt: dates.daysAgo(5),
      dateFrom: dates.daysAgo(2),
      checklistIds: [demoScrubberChecklistId],
    ),
    task(
      id: demoHumiditySpikeTaskId,
      title: t(
        'Trace the humidity spike in Bay C',
        'Feuchtigkeitsspitze in Bucht C aufspüren',
      ),
      description: t(
        'Nine points in three days is a leak, not weather. Bay C sits '
            'between the ice rink and the nursery, so a hidden leak there '
            'ends up in every feather on the station. The wall sensor is '
            'being swapped; once it reports again, walk the seam line with '
            'the thermal camera and either find the leak or clear the bay.',
        'Neun Punkte in drei Tagen sind ein Leck, kein Wetter. Bucht C '
            'liegt zwischen Eisbahn und Kinderstube — ein verstecktes Leck '
            'dort landet in allen Federn der Station. Der Wandsensor wird '
            'gerade getauscht; sobald er wieder meldet, lauft die '
            'Nahtlinie mit der Wärmebildkamera ab und findet das Leck oder '
            'gebt die Bucht frei.',
      ),
      status: TaskStatus.blocked(
        id: 'status-humidity-spike',
        createdAt: dates.daysAgo(3),
        utcOffset: 120,
        reason: t(
          'Waiting on the Bay C sensor swap',
          'Wartet auf den Sensortausch in Bucht C',
        ),
      ),
      priority: TaskPriority.p1High,
      due: dates.overdue(2),
      coverArtId: demoMediaCoverForTask(demoHumiditySpikeTaskId).id,
      labelIds: const [manualDemoCriticalLabelId, demoBlockedLabelId],
      estimate: const Duration(hours: 3),
      categoryId: demoHabitatCategoryId,
      createdAt: dates.daysAgo(8),
      dateFrom: dates.daysAgo(3),
    ),
    task(
      id: demoIceRinkTaskId,
      title: t(
        'Resurface the habitat ice rink',
        'Eisbahn im Habitat neu aufbereiten',
      ),
      description: t(
        'The colony rink has more grooves than ice. Book the resurfacer. '
            'Tobogganing practice starts again next month and the juniors '
            'keep catching their flippers in the ruts. Reserve the '
            'resurfacer for a quiet evening, close the rink for one '
            'session, and post the new ice rules before reopening.',
        'Die Kolonie-Eisbahn hat mehr Rillen als Eis. Bucht die Maschine. '
            'Nächsten Monat beginnt wieder das Rodeltraining, und die '
            'Junioren bleiben ständig mit den Flossen in den Rillen '
            'hängen. Reserviert die Maschine für einen ruhigen Abend, '
            'schließt die Bahn für eine Einheit und hängt vor der '
            'Wiedereröffnung die neuen Eisregeln aus.',
      ),
      status: openAt('ice-rink', 15),
      priority: TaskPriority.p3Low,
      due: dates.nextMonday(15),
      coverArtId: demoMediaCoverForTask(demoIceRinkTaskId).id,
      labelIds: const [],
      estimate: const Duration(hours: 2),
      categoryId: demoHabitatCategoryId,
      createdAt: dates.daysAgo(15),
      dateFrom: dates.daysAgo(15),
    ),
    task(
      id: demoSolarArrayTaskId,
      title: t(
        'Retune the solar array tilt',
        'Neigung der Solarfläche justieren',
      ),
      description: t(
        'Four degrees of drift is costing the habitat a third of its '
            'power. The tracking motor lost its calibration in the last '
            'dust storm and the batteries have dipped below reserve every '
            'night since. Recalibrate the tilt against the noon reference, '
            'verify the tracking curve over a full day, and log the '
            'recovered wattage.',
        'Vier Grad Abweichung kosten das Habitat ein Drittel seiner '
            'Leistung. Der Nachführmotor hat im letzten Staubsturm seine '
            'Kalibrierung verloren, und die Batterien rutschen seitdem '
            'jede Nacht unter die Reserve. Kalibriert die Neigung am '
            'Mittagsreferenzpunkt neu, prüft die Nachführkurve über einen '
            'ganzen Tag und protokolliert die zurückgewonnene Leistung.',
      ),
      status: groomedAt('solar-array', 6),
      priority: TaskPriority.p2Medium,
      due: dates.inDays(4, 12),
      coverArtId: demoMediaCoverForTask(demoSolarArrayTaskId).id,
      labelIds: const [demoResearchLabelId],
      estimate: const Duration(hours: 1, minutes: 30),
      categoryId: demoHabitatCategoryId,
      createdAt: dates.daysAgo(24),
      dateFrom: dates.daysAgo(6),
    ),
    task(
      id: demoWaterRecyclerTaskId,
      title: t('Service the water recycler', 'Wasseraufbereiter warten'),
      description: t(
        'Clean the filter housing and log the throughput afterwards. '
            'Routine service, but the last crew skipped the throughput log '
            'and Habitat Engineering had to guess the filter age. Do the '
            'full sequence this time: flush the loop, clean the housing, '
            'swap the pre-filter, and write the numbers down.',
        'Reinigt das Filtergehäuse und protokolliert danach den '
            'Durchsatz. Routinewartung — aber die letzte Crew hat das '
            'Durchsatzprotokoll ausgelassen, und die Habitat-Technik '
            'musste das Filteralter raten. Diesmal die volle Sequenz: '
            'Kreislauf spülen, Gehäuse reinigen, Vorfilter tauschen und '
            'die Zahlen aufschreiben.',
      ),
      status: doneAt('water-recycler', 5),
      priority: TaskPriority.p2Medium,
      due: dates.inDays(5, 9),
      coverArtId: demoMediaCoverForTask(demoWaterRecyclerTaskId).id,
      labelIds: const [],
      estimate: const Duration(hours: 1, minutes: 30),
      categoryId: demoHabitatCategoryId,
      createdAt: dates.daysAgo(27),
      dateFrom: dates.daysAgo(6, 13),
    ),
    // --- Cluster 3: logistics & supply ---------------------------------
    task(
      id: demoSquidPalletTaskId,
      title: t(
        'Find the missing squid pallet',
        'Verschwundene Tintenfisch-Palette finden',
      ),
      description: t(
        'Pallet 14 left Europa and never reached the cold ring. The dock '
            'scanner shows it entering bay two at 04:12, then nothing — '
            'and the squid inside has a five-day cold rating that runs out '
            'on Thursday. Trace the scan trail, search both bays, and '
            'either find the pallet or file the loss report before the '
            'insurance window closes.',
        'Palette 14 hat Europa verlassen und den Kühlring nie erreicht. '
            'Der Dock-Scanner zeigt sie um 04:12 in Bucht zwei, danach '
            'nichts — und der Tintenfisch darin hat eine Kühlfreigabe von '
            'fünf Tagen, die am Donnerstag abläuft. Verfolgt die '
            'Scan-Spur, durchsucht beide Buchten und findet die Palette — '
            'oder reicht die Verlustmeldung ein, bevor das '
            'Versicherungsfenster schließt.',
      ),
      status: runningAt('squid-pallet', 5),
      priority: TaskPriority.p1High,
      due: dates.today(17),
      coverArtId: demoMediaCoverForTask(demoSquidPalletTaskId).id,
      labelIds: const [manualDemoProjectLabelId],
      estimate: const Duration(hours: 1),
      categoryId: demoLogisticsCategoryId,
      createdAt: dates.daysAgo(6),
      dateFrom: dates.daysAgo(5),
      checklistIds: [demoPalletChecklistId],
    ),
    task(
      id: demoKrillSupplierTaskId,
      title: t(
        'Shortlist a second krill supplier',
        'Zweiten Krill-Lieferanten finden',
      ),
      description: t(
        'One supplier for the whole colony is one storm away from '
            'trouble. Procurement wants a second source signed before the '
            'winter contracts renew. Write down the criteria that actually '
            'matter — delivery time, cold-chain rating, price per tonne — '
            'collect quotes from at least three candidates, order a sample '
            'crate from the best two, and put a recommendation in front of '
            'the council.',
        'Ein Lieferant für die ganze Kolonie ist einen Sturm vom Problem '
            'entfernt. Der Einkauf will eine zweite Quelle unter Vertrag, '
            'bevor die Winterverträge verlängert werden. Schreibt die '
            'Kriterien auf, die wirklich zählen — Lieferzeit, '
            'Kühlketten-Bewertung, Preis pro Tonne —, holt Angebote von '
            'mindestens drei Kandidaten ein, bestellt bei den besten zwei '
            'eine Probekiste und legt dem Rat eine Empfehlung vor.',
      ),
      status: openAt('krill-supplier', 7),
      priority: TaskPriority.p2Medium,
      due: null,
      coverArtId: demoMediaCoverForTask(demoKrillSupplierTaskId).id,
      labelIds: const [demoResearchLabelId],
      estimate: const Duration(hours: 2),
      categoryId: demoLogisticsCategoryId,
      createdAt: dates.daysAgo(20),
      dateFrom: dates.daysAgo(7),
    ),
    task(
      id: demoShuttleManifestTaskId,
      title: t(
        'Reconcile the shuttle manifest',
        'Frachtliste des Shuttles abgleichen',
      ),
      description: t(
        'The manifest and the dock disagree by one pod. Find out which. '
            'Twenty-three pods on paper, twenty-four on the dock — and '
            'launch clearance needs the two lists to match to the pod. '
            'Count what is actually standing there, reconcile against the '
            'manifest line by line, and send the corrected list to Europa '
            'before the shuttle is loaded.',
        'Frachtliste und Dock unterscheiden sich um eine Kapsel. Findet '
            'heraus, welche. Dreiundzwanzig Kapseln auf dem Papier, '
            'vierundzwanzig am Dock — und die Startfreigabe braucht zwei '
            'Listen, die bis auf die Kapsel übereinstimmen. Zählt, was '
            'wirklich dort steht, gleicht Zeile für Zeile mit der '
            'Frachtliste ab und schickt die korrigierte Liste nach Europa, '
            'bevor das Shuttle beladen wird.',
      ),
      status: openAt('shuttle-manifest', 1),
      priority: TaskPriority.p2Medium,
      due: dates.tomorrow(9),
      coverArtId: demoMediaCoverForTask(demoShuttleManifestTaskId).id,
      labelIds: const [manualDemoProjectLabelId],
      estimate: const Duration(hours: 1),
      categoryId: demoLogisticsCategoryId,
      createdAt: dates.daysAgo(33),
      dateFrom: dates.daysAgo(1),
      checklistIds: [demoManifestChecklistId],
    ),
    task(
      id: demoPodSealOrderTaskId,
      title: t(
        'Order replacement pod seals',
        'Ersatzdichtungen für Kapseln bestellen',
      ),
      description: t(
        'Customs will not clear a pod whose seal certificate has expired. '
            'Eight pods run out of certificate next week and the seal '
            'supplier quotes ten days for delivery — the order is already '
            'five days late. Confirm the sizes against the pod register, '
            'place the rush order, and warn Logistics which pods will miss '
            'the next shuttle either way.',
        'Der Zoll gibt keine Kapsel frei, deren Dichtungszertifikat '
            'abgelaufen ist. Bei acht Kapseln läuft das Zertifikat nächste '
            'Woche ab, und der Lieferant nennt zehn Tage Lieferzeit — die '
            'Bestellung ist schon fünf Tage überfällig. Prüft die Größen '
            'gegen das Kapselregister, gebt die Eilbestellung auf und '
            'warnt die Logistik, welche Kapseln das nächste Shuttle so '
            'oder so verpassen.',
      ),
      status: openAt('pod-seal-order', 10),
      priority: TaskPriority.p1High,
      due: dates.overdue(5),
      coverArtId: demoMediaCoverForTask(demoPodSealOrderTaskId).id,
      labelIds: const [demoWaitingLabelId],
      estimate: const Duration(minutes: 30),
      categoryId: demoLogisticsCategoryId,
      createdAt: dates.daysAgo(10),
      dateFrom: dates.daysAgo(10),
    ),
    task(
      id: demoCustomsEuropaTaskId,
      title: t('Clear customs on Europa', 'Zoll auf Europa erledigen'),
      description: t(
        'File the seal certificates and the passenger question together. '
            'Europa customs reopens Monday, and they process bundled '
            'filings faster than loose paperwork. Have the certificate '
            'folder, the passenger ruling request, and the manifest copy '
            'ready in one envelope so the whole stack clears in a single '
            'visit.',
        'Reicht die Dichtungszertifikate und die Passagierfrage zusammen '
            'ein. Der Zoll von Europa öffnet am Montag wieder — und '
            'gebündelte Anträge bearbeitet er schneller als lose Zettel. '
            'Legt den Zertifikatsordner, die Anfrage zur Passagierfrage '
            'und die Kopie der Frachtliste in einen Umschlag, damit der '
            'ganze Stapel bei einem Besuch durchgeht.',
      ),
      status: TaskStatus.onHold(
        id: 'status-customs-europa',
        createdAt: dates.daysAgo(8),
        utcOffset: 120,
        reason: t(
          'Europa customs is closed until Monday',
          'Der Zoll von Europa ist bis Montag geschlossen',
        ),
      ),
      priority: TaskPriority.p2Medium,
      due: dates.inDays(3, 17),
      coverArtId: demoMediaCoverForTask(demoCustomsEuropaTaskId).id,
      labelIds: const [demoWaitingLabelId],
      estimate: const Duration(hours: 1),
      categoryId: demoLogisticsCategoryId,
      createdAt: dates.daysAgo(18),
      dateFrom: dates.daysAgo(8),
    ),
    // --- Cluster 4: colony life ----------------------------------------
    task(
      id: demoColonyNewsletterTaskId,
      title: t('Write the colony newsletter', 'Koloniebrief schreiben'),
      description: t(
        'Four sections, one photo, and no more than one fish pun. The '
            'colony reads it over breakfast, so keep it short and warm: '
            'what happened, what is coming, who hatched, and what the '
            'kitchen is planning. The launch update must match what Comms '
            'announces — check with them before printing.',
        'Vier Abschnitte, ein Foto und höchstens ein Fischwitz. Die '
            'Kolonie liest ihn beim Frühstück — also kurz und warm: was '
            'war, was kommt, wer geschlüpft ist und was die Küche plant. '
            'Das Start-Update muss zu dem passen, was Comms verkündet — '
            'fragt dort nach, bevor gedruckt wird.',
      ),
      status: openAt('colony-newsletter', 4),
      priority: TaskPriority.p3Low,
      due: dates.tomorrow(9),
      coverArtId: demoMediaCoverForTask(demoColonyNewsletterTaskId).id,
      labelIds: const [],
      estimate: const Duration(hours: 1),
      createdAt: dates.daysAgo(14),
      dateFrom: dates.daysAgo(4),
      checklistIds: [demoNewsletterChecklistId],
    ),
    task(
      id: demoChickDaycareTaskId,
      title: t(
        'Refill the chick daycare rota',
        'Dienstplan der Kükenbetreuung füllen',
      ),
      description: t(
        'Thursday lost two volunteers and the chicks noticed immediately. '
            'The rota needs two names per shift or the nursery closes '
            'early, and early closing means chicks at the launch briefing '
            'again. Ask the reserve list first, then post the open shifts '
            'on the colony board, and confirm the full week by Friday.',
        'Am Donnerstag fehlen zwei Freiwillige, und die Küken haben es '
            'sofort gemerkt. Der Dienstplan braucht zwei Namen pro '
            'Schicht, sonst schließt die Kinderstube früher — und das '
            'heißt wieder Küken im Start-Briefing. Fragt zuerst die '
            'Reserveliste, hängt dann die offenen Schichten ans '
            'Koloniebrett und bestätigt die volle Woche bis Freitag.',
      ),
      status: groomedAt('chick-daycare', 16),
      priority: TaskPriority.p2Medium,
      due: dates.inDays(5, 17),
      coverArtId: demoMediaCoverForTask(demoChickDaycareTaskId).id,
      labelIds: const [demoWaitingLabelId],
      estimate: const Duration(minutes: 45),
      createdAt: dates.daysAgo(16),
      dateFrom: dates.daysAgo(16),
    ),
    task(
      id: demoMovieNightTaskId,
      title: t(
        'Pick the film for colony night',
        'Film für den Kolonieabend wählen',
      ),
      description: t(
        'The colony voted for the ice documentary. Book the dome. The '
            'distributor needs three days of notice for the screening '
            'licence, and the dome heater has to be off for two hours '
            'before anyone brings blankets. Book the licence, reserve the '
            'dome, and put the start time on the colony board.',
        'Die Kolonie hat für die Eis-Doku gestimmt. Bucht die Kuppel. Der '
            'Verleih braucht drei Tage Vorlauf für die Vorführlizenz, und '
            'die Kuppelheizung muss zwei Stunden vorher aus sein, bevor '
            'jemand Decken mitbringt. Bucht die Lizenz, reserviert die '
            'Kuppel und schreibt die Anfangszeit ans Koloniebrett.',
      ),
      status: openAt('movie-night', 18),
      priority: TaskPriority.p3Low,
      due: dates.nextMonday(12, plusDays: 2),
      coverArtId: demoMediaCoverForTask(demoMovieNightTaskId).id,
      labelIds: const [],
      estimate: const Duration(minutes: 20),
      createdAt: dates.daysAgo(18),
      dateFrom: dates.daysAgo(18),
    ),
    task(
      id: demoTobogganingTaskId,
      title: t('Restart the tobogganing league', 'Rodel-Liga wieder starten'),
      description: t(
        'Softer landings first, then a rematch against Bay C. The league '
            'stopped after two bruised tails and one very formal '
            'complaint. Pile fresh snow on the run-out, set a weight limit '
            'for the doubles sled, and only then challenge Bay C — they '
            'have been practising.',
        'Erst weichere Landungen, dann ein Rückspiel gegen Bucht C. Die '
            'Liga hat nach zwei geprellten Schwänzen und einer sehr '
            'förmlichen Beschwerde pausiert. Schaufelt frischen Schnee in '
            'den Auslauf, setzt ein Gewichtslimit für den Doppelschlitten '
            'und fordert erst dann Bucht C heraus — die haben geübt.',
      ),
      status: groomedAt('tobogganing', 21),
      priority: TaskPriority.p3Low,
      due: null,
      coverArtId: demoMediaCoverForTask(demoTobogganingTaskId).id,
      labelIds: const [],
      estimate: const Duration(hours: 1),
      createdAt: dates.daysAgo(21),
      dateFrom: dates.daysAgo(21),
    ),
  ];
}
