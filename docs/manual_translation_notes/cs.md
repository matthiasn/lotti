# Poznámky k českému překladu příručky

Zde shromažďujeme pozorování vzniklá při porovnávání české příručky s
produkční aplikací. Tato větev opravuje jen jednoznačné české štítky, které
jsou vidět v příručce; sporné, technické nebo pevně dané texty zůstávají zde
pro samostatnou lokalizační práci.

## Postup

- Zapsat aktuální text, dotčený klíč ARB a obrazovku.
- Stručně vysvětlit, proč formulace působí nejasně, nepřirozeně nebo
  nekonzistentně.
- Volitelně uvést možný směr pozdější opravy nebo technické omezení.
- Uvedený problém neměnit bez ověření zdroje a bez snímku po úpravě.

## Pozorování

| Obrazovka | Aktuální text | Pozorování |
| --- | --- | --- |
| Nahrávání zvuku | `Speech Recognition` | Text zaškrtávacího pole je ve widgetu pevně anglicky, a proto zůstává anglický také v české variantě aplikace. |
| Nahrávání zvuku | `STOP` | Popisek akce zastavení nahrávání je ve widgetu pevně anglicky, a proto se v české variantě aplikace nepřeloží. |
| Uložené přepisy | `Vyberte jazyk`, `English`, `Lang`, `Model` | Výběr jazyka používá formální oslovení a anglické názvy voleb i popisky metadat. To neodpovídá neformální češtině zbytku aplikace. |
| Počítačová navigace | `Daily OS`, případně další anglické cíle | Produktové názvy mohou být záměrné; při kontrole snímků je potřeba rozlišit záměrné názvy od chybějící lokalizace. |
| Panely a přehledy | `Panely`, `Přehledy` | Nastavení používá „Panely“, hlavní navigace „Přehledy“. Příručka zachovává přesný název obrazovky, v souvislém textu používá přirozenější „přehled“. Před plošným sjednocením je potřeba rozhodnout, zda rozlišení vyjadřuje dva různé kontexty. |
| Zdroje grafů | `Průzkumy`, `Cvičení` | Pro vestavěné dotazníky a importované tréninky by bylo vhodné ověřit terminologii napříč aplikací; příručka zachovává aktuální názvy ovládacích prvků. |
| Výběr ikony kategorie | `Flight` | Samotný název ikony zůstává anglický. Nejde o klíč ARB, proto je před případným překladem potřeba ověřit původ a dopad na vyhledávání ikon. |
| Statistiky synchronizace | `Top KPIs` | Popisek karty je ve snímku anglicky. Před opravou ověřit, zda pochází z nativního grafu nebo z pevného textu aplikace. |
| Složité technické pojmy | `embeddings`, `Matrix`, `homeserver` | Příručka je zatím používá střídmě a podle souvislosti. Před terminologickou úpravou je potřeba zvolit ustálené české ekvivalenty a nepřeložit názvy protokolů či produktů chybně. |

## Opraveno v této větvi

| Oblast | Oprava | Poznámka k ověření |
| --- | --- | --- |
| Kategorie | Nápovědy a popisy nyní používají neformální `Vyber` a `Nastav`. | Po `make l10n` znovu zachytit editor kategorie; anglický název ikony `Flight` zůstává otevřený. |
| Panely | Popisky `dashboard*` již neobsahují anglické „dashboard“ a používají „panel“. | Ověřit seznam a editor panelu na mobilu i počítači. |
| Návyky a poznámky | Výběr kategorie/panelu, smazání návyku a zástupný text poznámek jsou neformální. | Ověřit formulář návyku a podrobnost úkolu. |
| Analýza času | „Fokusové kategorie“ jsou nyní „Sledované kategorie“; příručka používá skutečný štítek `FOKUS`. | Znovu zachytit přehled i panel výběru kategorií. |
| Hodnocení sezení a reference obrázků | Klíče `sessionRating*` a `referenceImage*` jsou neformální a používají přirozenější „sezení“. | Znovu zachytit formulář hodnocení a výběr referenčních obrázků. |
| Nastavení synchronizace | „Provizní synchronizace“ je nyní „Nastavení synchronizace“ a párovací balíček má konzistentní název. | Znovu zachytit centrum Sync, QR kód i importní panel. |
| Časová osa Daily OS | Nápověda přejíždění teď odkazuje přímo na kartu `Skutečnost`. | Ověřit na úzkém mobilním snímku. |
| PANAS | ARB už obsahuje české pokyny, odpovědi i tlačítko `Další`; příručka už nepopisuje zastaralou anglickou variantu. | Povinně znovu zachytit oba snímky PANAS v českém prostředí. |

Pevně anglické texty v nahrávacím widgetu a další otevřené body zůstávají
konkrétním podkladem pro následnou, samostatně ověřenou lokalizační práci.
