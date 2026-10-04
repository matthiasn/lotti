part of 'demo_world.dart';

// The larger content sections of `ManualDemoWorld.penguinLogistics`, moved
// verbatim: each takes the factory's helpers (which close over its clock,
// category and translation) under the names the section always used.

typedef _TaskBuilder =
    Task Function({
      required String id,
      required String title,
      required String description,
      required TaskStatus status,
      required TaskPriority priority,
      required DateTime? due,
      required String? coverArtId,
      required List<String> labelIds,
      required Duration estimate,
      List<String>? checklistIds,
      String categoryId,
      DateTime? createdAt,
      DateTime? dateFrom,
    });

typedef _StatusAt = TaskStatus Function(String slug, int daysBack);

typedef _NoteBuilder =
    JournalEntry Function({
      required String id,
      required String text,
      required DateTime from,
      DateTime? to,
      String categoryId,
    });

typedef _TimeRecordBuilder =
    JournalEntry Function({
      required String id,
      required String text,
      required int weekdaysBack,
      required int hour,
      required Duration duration,
      String categoryId,
    });

typedef _HabitBuilder =
    HabitDefinition Function({
      required String id,
      required String name,
      required String description,
      String? categoryId,
      HabitSchedule? schedule,
      DateTime? activeFrom,
      bool priority,
      bool private,
      bool active,
    });

List<JournalEntry> _penguinNotes({
  required DemoSeedText t,
  required DemoDates dates,
  required _NoteBuilder note,
}) {
  return <JournalEntry>[
    note(
      id: demoUuid('note-seal-pressure'),
      from: dates.daysAgo(1, 8),
      text: t(
        'Bay A seals held 101.3 kPa all night.',
        'Die Dichtungen in Bucht A hielten die ganze Nacht 101,3 kPa.',
      ),
    ),
    note(
      id: demoUuid('note-scrubber-order'),
      from: dates.daysAgo(2, 11),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Cartridge order confirmed, arrives on the next shuttle.',
        'Patronenbestellung bestätigt, kommt mit dem nächsten Shuttle.',
      ),
    ),
    note(
      id: demoUuid('note-humidity-reading'),
      from: dates.daysAgo(3, 15),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Bay C is at 78% humidity, nine points up since Tuesday.',
        'Bucht C liegt bei 78 % Luftfeuchte, neun Punkte mehr als am Dienstag.',
      ),
    ),
    note(
      id: demoUuid('note-feeder-trajectory'),
      from: dates.daysAgo(4, 10),
      text: t(
        'The feeder still aims lunch at Mission Control.',
        'Der Automat zielt mit dem Mittagessen weiter auf die '
            'Missionskontrolle.',
      ),
    ),
    note(
      id: demoUuid('note-pallet-search'),
      from: dates.daysAgo(5, 14),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'Pallet 14 is not in bay two. Checking the cold ring next.',
        'Palette 14 ist nicht in Bucht zwei. Als Nächstes prüfe ich den '
            'Kühlring.',
      ),
    ),
    note(
      id: demoUuid('note-krill-quote'),
      from: dates.daysAgo(7),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'Europa Krill quoted 12% below our current supplier.',
        'Europa Krill bietet 12 % unter unserem jetzigen Lieferanten.',
      ),
    ),
    note(
      id: demoUuid('note-customs-form'),
      from: dates.daysAgo(8, 16),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'Customs wants the pod seal certificates before Friday.',
        'Der Zoll will die Zertifikate der Kapseldichtungen vor Freitag.',
      ),
    ),
    note(
      id: demoUuid('note-weather-window'),
      from: dates.daysAgo(9, 7),
      text: t(
        'The ice pad clears at 06:40 with a light crosswind.',
        'Der Eisstartplatz ist ab 06:40 frei, bei leichtem Seitenwind.',
      ),
    ),
    note(
      id: demoUuid('note-rehearsal-gap'),
      from: dates.daysAgo(10, 17),
      text: t(
        'Rehearsal ran nine minutes long on the boarding step.',
        'Die Probe dauerte beim Einsteigen neun Minuten zu lang.',
      ),
    ),
    note(
      id: demoUuid('note-suit-sizes'),
      from: dates.daysAgo(12, 13),
      text: t(
        'Three flight suits need a wider flipper cut.',
        'Drei Fluganzüge brauchen einen weiteren Flossenschnitt.',
      ),
    ),
    note(
      id: demoUuid('note-newsletter-draft'),
      from: dates.daysAgo(14, 20),
      text: t(
        'The draft is done except for the launch section.',
        'Der Entwurf steht, bis auf den Startabschnitt.',
      ),
    ),
    note(
      id: demoUuid('note-daycare-rota'),
      from: dates.daysAgo(16, 8),
      text: t(
        'Two volunteers dropped out of the Thursday slot.',
        'Zwei Freiwillige sind für den Donnerstag abgesprungen.',
      ),
    ),
    note(
      id: demoUuid('note-movie-vote'),
      from: dates.daysAgo(18, 21),
      text: t(
        'The colony voted for the documentary about ice.',
        'Die Kolonie hat für die Doku über Eis gestimmt.',
      ),
    ),
    note(
      id: demoUuid('note-toboggan-injury'),
      from: dates.daysAgo(21, 15),
      text: t(
        'One sprained flipper, so we need softer landings.',
        'Eine verstauchte Flosse, wir brauchen weichere Landungen.',
      ),
    ),
    note(
      id: demoUuid('note-solar-tilt'),
      from: dates.daysAgo(24, 11),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Tilt is four degrees off after the last burn.',
        'Die Neigung liegt nach dem letzten Manöver vier Grad daneben.',
      ),
    ),
    note(
      id: demoUuid('note-recycler-filter'),
      from: dates.daysAgo(27),
      categoryId: demoHabitatCategoryId,
      text: t(
        'The recycler filter was clogged with feather down.',
        'Der Filter des Aufbereiters war mit Daunen verstopft.',
      ),
    ),
    note(
      id: demoUuid('note-freezer-log'),
      from: dates.daysAgo(30, 12),
      text: t(
        'Freezer 3 logged a two-hour gap on Sunday.',
        'Kühler 3 hat am Sonntag eine Lücke von zwei Stunden protokolliert.',
      ),
    ),
    note(
      id: demoUuid('note-manifest-mismatch'),
      from: dates.daysAgo(33, 10),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'The manifest says 40 pods, the dock counted 39.',
        'Die Frachtliste nennt 40 Kapseln, am Dock wurden 39 gezählt.',
      ),
    ),
    note(
      id: demoUuid('note-comms-tone'),
      from: dates.daysAgo(37, 18),
      text: t(
        'Mission Control wants fewer fish puns in the launch script.',
        'Die Missionskontrolle will weniger Fischwitze im Startskript.',
      ),
    ),
    note(
      id: demoUuid('note-roll-call-late'),
      from: dates.daysAgo(40, 19),
      text: t(
        'Sir Flaps-a-Lot answered roll call from the cargo netting.',
        'Sir Flatterviel meldete sich beim Appell aus dem Frachtnetz.',
      ),
    ),
    note(
      id: demoUuid('note-lunch-wellness'),
      from: dates.daysAgo(1, 13),
      text: t(
        'Eat something recognizable as food before the robot nutritionist '
            'files another orbital wellness incident.',
        'Iss etwas, das als Essen erkennbar ist, bevor der '
            'Roboter-Ernährungsberater den nächsten orbitalen '
            'Gesundheitsvorfall meldet.',
      ),
    ),
  ];
}

List<JournalEntry> _penguinExpansionTimeRecords({
  required DemoSeedText t,
  required _TimeRecordBuilder timeRecord,
}) {
  return <JournalEntry>[
    timeRecord(
      id: demoUuid('time-scrubber-swap'),
      weekdaysBack: 1,
      hour: 9,
      duration: const Duration(hours: 1, minutes: 25),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Swapped cartridges in Bay A and B.',
        'Patronen in Bucht A und B getauscht.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-humidity-hunt'),
      weekdaysBack: 1,
      hour: 14,
      duration: const Duration(hours: 2),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Two hours chasing the humidity leak, no source yet.',
        'Zwei Stunden dem Feuchtigkeitsleck nachgejagt, noch keine Quelle.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-pallet-walk'),
      weekdaysBack: 2,
      hour: 10,
      duration: const Duration(minutes: 50),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'Walked the whole cold ring looking for pallet 14.',
        'Den ganzen Kühlring nach Palette 14 abgelaufen.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-rehearsal-run'),
      weekdaysBack: 2,
      hour: 15,
      duration: const Duration(hours: 1, minutes: 40),
      text: t(
        'Full rehearsal run with the boarding crew.',
        'Komplette Probe mit der Einsteigemannschaft.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-freezer-audit'),
      weekdaysBack: 3,
      hour: 11,
      duration: const Duration(hours: 2, minutes: 15),
      text: t(
        'Reconciled two weeks of freezer logs.',
        'Zwei Wochen Kühlprotokolle abgeglichen.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-newsletter-draft'),
      weekdaysBack: 4,
      hour: 16,
      duration: const Duration(minutes: 45),
      text: t(
        'Wrote the colony newsletter draft.',
        'Den Entwurf für den Koloniebrief geschrieben.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-solar-measure'),
      weekdaysBack: 5,
      hour: 9,
      duration: const Duration(hours: 1),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Measured the array tilt against the sun sensor.',
        'Die Neigung der Solarfläche am Sonnensensor gemessen.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-recycler-clean'),
      weekdaysBack: 6,
      hour: 13,
      duration: const Duration(hours: 1, minutes: 10),
      categoryId: demoHabitatCategoryId,
      text: t(
        'Cleaned the recycler filter housing.',
        'Das Filtergehäuse des Aufbereiters gereinigt.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-manifest-count'),
      weekdaysBack: 7,
      hour: 10,
      duration: const Duration(minutes: 55),
      categoryId: demoLogisticsCategoryId,
      text: t(
        'Counted pods on the dock with the shuttle crew.',
        'Kapseln am Dock mit der Shuttle-Crew gezählt.',
      ),
    ),
    timeRecord(
      id: demoUuid('time-comms-rewrite'),
      weekdaysBack: 8,
      hour: 14,
      duration: const Duration(minutes: 35),
      text: t(
        'Rewrote the launch script intro.',
        'Die Einleitung des Startskripts neu geschrieben.',
      ),
    ),
  ];
}

List<HabitDefinition> _penguinHabits({
  required DemoSeedText t,
  required DemoDates dates,
  required _HabitBuilder habit,
}) {
  return <HabitDefinition>[
    habit(
      id: manualRollCallHabitId,
      name: t('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
      description: t(
        'Account for all 37 expedition penguins before launch.',
        'Vor dem Start alle 37 Expeditionspinguine erfassen.',
      ),
      categoryId: manualDemoCategoryId,
      schedule: HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: dates.today(6),
        alertAtTime: dates.today(6, 30),
      ),
      // Well before the completion history below, so the habit does not
      // look like it started mid-streak.
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
      priority: true,
    ),
    habit(
      id: manualHabitatSealsHabitId,
      name: t('Walk the habitat seals', 'Habitatdichtungen ablaufen'),
      description: t(
        'Inspect every pressure seal after the artificial sunrise.',
        'Nach dem künstlichen Sonnenaufgang jede Druckdichtung inspizieren.',
      ),
      categoryId: manualDemoCategoryId,
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
      private: true,
    ),
    // Retired on purpose: the habits page has a distinct treatment for an
    // inactive habit, and a world where every habit is live never shows
    // it. It carries no completions for the same reason.
    habit(
      id: manualSardineForecastHabitId,
      name: t('Review sardine forecast', 'Sardinenprognose prüfen'),
      description: t(
        'Paused while the Europa exchange recalibrates its fish index.',
        'Pausiert, während die Europa-Börse ihren Fischindex neu kalibriert.',
      ),
      categoryId: demoLogisticsCategoryId,
      active: false,
    ),
    habit(
      id: demoColdChainTelemetryHabitId,
      name: t(
        'Check cold-chain telemetry',
        'Kühlketten-Telemetrie prüfen',
      ),
      description: t(
        'Scan overnight freezer readings before the first cargo handoff.',
        'Prüfe vor der ersten Frachtübergabe die nächtlichen '
            'Kühlraumwerte.',
      ),
      categoryId: demoLogisticsCategoryId,
      schedule: HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: dates.today(7),
        alertAtTime: dates.today(7, 15),
      ),
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
      priority: true,
    ),
    habit(
      id: demoOutboundManifestHabitId,
      name: t(
        'Reconcile outbound cargo manifest',
        'Ausgehende Frachtliste abgleichen',
      ),
      description: t(
        'Match every pod, pallet, and penguin signature before departure.',
        'Gleiche vor dem Abflug jede Kapsel, Palette und '
            'Pinguin-Unterschrift ab.',
      ),
      categoryId: demoLogisticsCategoryId,
      schedule: HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: dates.today(8),
        alertAtTime: dates.today(8, 30),
      ),
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
    ),
    habit(
      id: demoShiftHandoffHabitId,
      name: t(
        'Send the end-of-shift handoff',
        'Schichtübergabe senden',
      ),
      description: t(
        'Leave the next specialist a crisp update, including any drifting '
            'fish.',
        'Hinterlasse der nächsten Fachkraft ein klares Update, '
            'einschließlich abdriftender Fische.',
      ),
      categoryId: manualDemoCategoryId,
      schedule: HabitSchedule.daily(
        requiredCompletions: 1,
        showFrom: dates.today(17),
        alertAtTime: dates.today(17, 45),
      ),
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
    ),
    habit(
      id: demoFlipperMobilityHabitId,
      name: t(
        'Zero-gravity flipper mobility',
        'Flossen-Mobilität in Schwerelosigkeit',
      ),
      description: t(
        'Complete three gentle mobility sessions before the weekly cargo '
            'sprint.',
        'Absolviere vor dem wöchentlichen Frachtsprint drei sanfte '
            'Mobilitätseinheiten.',
      ),
      categoryId: manualDemoCategoryId,
      schedule: const HabitSchedule.weekly(requiredCompletions: 3),
      activeFrom: dates.daysAgo(_habitHistoryDays + 7),
      private: true,
    ),
  ];
}

typedef _CompletionBuilder =
    HabitCompletionEntry Function({
      required String habitId,
      required int daysAgo,
      required HabitCompletionType type,
      required int hour,
      String categoryId,
    });

/// The habits' lived-in history: a near-unbroken roll call with one
/// skipped day, a patchier seal walk with a genuine failure, both stopping
/// short of today so the demo opens with something left to tick off.
List<HabitCompletionEntry> _penguinHabitCompletions({
  required _CompletionBuilder completion,
}) {
  return <HabitCompletionEntry>[
    for (var day = _habitHistoryDays; day >= 1; day--)
      if (day != 5)
        completion(
          habitId: manualRollCallHabitId,
          daysAgo: day,
          type: day == 9
              ? HabitCompletionType.skip
              : (HabitCompletionType.success),
          hour: 6,
        ),
    for (var day = _habitHistoryDays; day >= 1; day--)
      if (day % 3 != 0)
        completion(
          habitId: manualHabitatSealsHabitId,
          daysAgo: day,
          type: day == 4
              ? HabitCompletionType.fail
              : (HabitCompletionType.success),
          hour: 7,
        ),
    for (var day = _habitHistoryDays; day >= 1; day--)
      if (day % 7 != 0)
        completion(
          habitId: demoColdChainTelemetryHabitId,
          daysAgo: day,
          type: day == 11
              ? HabitCompletionType.skip
              : HabitCompletionType.success,
          hour: 7,
          categoryId: demoLogisticsCategoryId,
        ),
    for (var day = _habitHistoryDays; day >= 1; day--)
      if (day % 4 != 0)
        completion(
          habitId: demoOutboundManifestHabitId,
          daysAgo: day,
          type: day == 13
              ? HabitCompletionType.fail
              : HabitCompletionType.success,
          hour: 8,
          categoryId: demoLogisticsCategoryId,
        ),
    for (var day = _habitHistoryDays; day >= 1; day--)
      if (day % 5 != 0)
        completion(
          habitId: demoShiftHandoffHabitId,
          daysAgo: day,
          type: day == 6
              ? HabitCompletionType.skip
              : HabitCompletionType.success,
          hour: 17,
        ),
    for (final day in const [27, 25, 22, 20, 18, 15, 13, 11, 8, 6, 4, 2])
      completion(
        habitId: demoFlipperMobilityHabitId,
        daysAgo: day,
        type: day == 13
            ? HabitCompletionType.skip
            : HabitCompletionType.success,
        hour: 18,
      ),
  ];
}
