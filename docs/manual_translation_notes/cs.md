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
| Počítačová navigace | `Daily OS`, případně další anglické cíle | Produktové názvy mohou být záměrné; při kontrole snímků je potřeba rozlišit záměrné názvy od chybějící lokalizace. |
| Panely a přehledy | `Panely`, `Přehledy`, `Název dashboardu`, `Grafy na tomto dashboardu` | Stejný koncept používá několik českých názvů a dva popisky navíc přebírají anglické „dashboard“. Příručka používá pro navigaci aktuální názvy obrazovek a v souvislém textu přirozenější „přehled“. |
| Zdroje grafů | `Průzkumy`, `Cvičení` | Pro vestavěné dotazníky a importované tréninky by bylo vhodné ověřit terminologii napříč aplikací; příručka zachovává aktuální názvy ovládacích prvků. |
| Výběr ikony kategorie | `Flight`, `Vyberte jinou ikonu` | Název ikony zůstává anglický a nápověda používá formální oslovení, které neodpovídá neformálnímu tónu aplikace. |
| Hodnocení sezení | `Ohodnoťte tuto relaci`, `Jak energický/á jste se cítil/a?`, `Jak soustředění jste byli?` | Klíče `sessionRating*` míchají formální oslovení s neformálním tónem zbytku aplikace a používají méně přirozené „relace“. Příručka používá neformální „sezení“. |
| Výběr referenčních obrázků | `Vyberte referenční obrázky` | Klíč `referenceImageSelectionTitle` používá formální imperativ, zatímco příručka i ostatní obrazovky mluví neformálně. |
| Zprovoznění synchronizace | `Provizní synchronizace` | Klíč `provisionedSyncTitle` působí jako doslovný překlad anglického „provisioned“. V kontextu importu zabezpečeného párovacího balíčku by potřeboval přirozenější české pojmenování. |
| Karta agenta úkolu | `Proposed changes`, `pending`, `Confirm all` | Nástroje pro návrhy agenta zůstávají na jinak české kartě anglicky. Příručka používá viditelný název `Confirm all`, aby se čtenář mohl v aktuální aplikaci zorientovat. |
| Podrobnost úkolu | `Zadejte poznámky…` | Zástupný text poznámek používá formální imperativ, který neodpovídá neformálnímu tónu zbytku českého rozhraní. |
| Kontroly šablon a duší agentů | `Current Proposal`, `Session History`, `Start Conversation`, `Edit Template` | Ovládací prvky a názvy sekcí pro individuální kontroly agentů se ve snímcích zobrazují anglicky. S výrazy „Duše 1-on-1“ vedle nich vzniká směs tří stylů. |
| Časová osa Daily OS | `Přejeď na skutečnost` | Popisek gesta působí jako doslovný překlad a není jasné, že má přepnout z plánované na zaznamenanou stopu. Přirozenější by byl směr typu „Přepni na skutečný čas“. |

Tyto body se v PR příručky neopravují v lokalizaci aplikace. Slouží jako
konkrétní podklad pro pozdější samostatnou lokalizační práci.
