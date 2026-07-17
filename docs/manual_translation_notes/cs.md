# Poznámky k českému překladu příručky

Zde shromažďujeme pozorování vzniklá při porovnávání české příručky s
produkční aplikací. Jsou pouze informativní: práce na příručce nemění překlady
aplikace bez samostatné lokalizační změny.

## Postup

- Zapsat aktuální text, dotčený klíč ARB a obrazovku.
- Stručně vysvětlit, proč formulace působí nejasně, nepřirozeně nebo
  nekonzistentně.
- Volitelně uvést možný směr pozdější opravy.
- Žádnou změnu zde nepovažovat za schválenou.

## Pozorování

| Obrazovka | Aktuální text | Pozorování |
| --- | --- | --- |
| Nahrávání zvuku | `Speech Recognition` | Text zaškrtávacího pole je ve widgetu pevně anglicky, a proto zůstává anglický také v české variantě aplikace. |
| Nahrávání zvuku | `STOP` | Popisek akce zastavení nahrávání je ve widgetu pevně anglicky, a proto se v české variantě aplikace nepřeloží. |
| Uložené přepisy | `Vyberte jazyk`, `English`, `Lang`, `Model` | Výběr jazyka používá formální oslovení a anglické názvy voleb i popisky metadat. To neodpovídá neformální češtině zbytku aplikace. |
| Co je nového | `NEW` | Označení nejnovější verze v hlavním banneru je pevně anglicky. |
| Metriky Sync | `Top KPIs`, `Processed` | Oba popisky grafů jsou v metrickém widgetu pevně anglicky. |
| Metriky průvodce | `Reached real aha` | Interní název události zůstává v českém pohledu anglicky. |
| Počítačová navigace | `Daily OS`, případně další anglické cíle | Produktové názvy mohou být záměrné; při kontrole snímků je potřeba rozlišit záměrné názvy od chybějící lokalizace. |
| Úvodní průvodce | `Onboarding`, `Zopakovat onboarding` | Klíče `settingsOnboardingTitle` a `settingsOnboardingReplayTitle` míchají angličtinu s češtinou, zatímco příručka používá přirozenější „Úvodní průvodce“. |
| Nastavení agentů | `Agents`, `Templates, instances, and monitoring` | Klíče `agentSettingsTitle` a `agentSettingsSubtitle` v českém ARB chybějí a aplikace proto zobrazuje anglický náhradní text. |
| Panely a přehledy | `Panely`, `Přehledy`, `Název dashboardu`, `Grafy na tomto dashboardu` | Stejný koncept používá několik českých názvů a dva popisky navíc přebírají anglické „dashboard“. Příručka používá pro navigaci aktuální názvy obrazovek a v souvislém textu přirozenější „přehled“. |
| Zdroje grafů | `Průzkumy`, `Cvičení` | Pro vestavěné dotazníky a importované tréninky by bylo vhodné ověřit terminologii napříč aplikací; příručka zachovává aktuální názvy ovládacích prvků. |
| Dotazníky PANAS | Pokyny, položky, škála odpovědí a `NEXT` | Při českém prostředí zůstává celý obsah vestavěného dotazníku PANAS anglicky, zatímco okolní přehled je česky. Příručka to výslovně uvádí, aby odpovídala snímku; samotný překlad nástroje je samostatné produktové rozhodnutí. |
| Výběr ikony kategorie | `Flight`, `Vyberte jinou ikonu` | Název ikony zůstává anglický a nápověda používá formální oslovení, které neodpovídá neformálnímu tónu aplikace. |
| Hodnocení sezení | `Ohodnoťte tuto relaci`, `Jak energický/á jste se cítil/a?`, `Jak soustředění jste byli?` | Klíče `sessionRating*` míchají formální oslovení s neformálním tónem zbytku aplikace a používají méně přirozené „relace“. Příručka používá neformální „sezení“. |
| Výběr referenčních obrázků | `Vyberte referenční obrázky` | Klíč `referenceImageSelectionTitle` používá formální imperativ, zatímco příručka i ostatní obrazovky mluví neformálně. |
| Diagnostika Matrix Sync | `Show Diagnostic Info` | Klíč `settingsMatrixDiagnosticShowButton` nemá český překlad a v aplikaci se zobrazí anglický náhradní text. |
| Zprovoznění synchronizace | `Provizní synchronizace` | Klíč `provisionedSyncTitle` působí jako doslovný překlad anglického „provisioned“. V kontextu importu zabezpečeného párovacího balíčku by potřeboval přirozenější české pojmenování. |
| Nastavení AI – profily | `Inference Profiles`, `Edit Profile`, `Thinking`, `Image Recognition`, `Transcription`, `Image Generation` | Na několika obrazovkách profilů inference zůstávají nadpisy a názvy pozic anglicky. Je potřeba rozlišit modelová ID od běžných ovládacích prvků a přeložit druhé z nich. |
| Nastavení agentů | `Agents`, `Stats`, `Agent Templates`, `Instances`, `Due` | Kromě dříve zaznamenaného titulku nastavení zůstávají anglické i názvy hlavních záložek a stavů. Na české obrazovce působí jako neúplná lokalizace. |
| Kontroly šablon a duší agentů | `Current Proposal`, `Session History`, `Start Conversation`, `Edit Template` | Ovládací prvky a názvy sekcí pro individuální kontroly agentů se ve snímcích zobrazují anglicky. S výrazy „Duše 1-on-1“ vedle nich vzniká směs tří stylů. |
| Časová osa Daily OS | `Přejeď na skutečnost` | Popisek gesta působí jako doslovný překlad a není jasné, že má přepnout z plánované na zaznamenanou stopu. Přirozenější by byl směr typu „Přepni na skutečný čas“. |

Tyto body se v PR příručky neopravují v lokalizaci aplikace. Slouží jako
konkrétní podklad pro pozdější samostatnou lokalizační práci.
