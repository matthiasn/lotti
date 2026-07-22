/// Tutorial-video driver: "turn a coding task into an AI-ready prompt".
///
/// Drives the real app through the scenario in
/// `tools/tutorial_videos/config/scenarios/task_coding_prompt.yaml`:
///
///  1. open a complex coding task (description + checklist) that carries a
///     linked text note with the "current situation",
///  2. run the "Generate Coding Prompt" skill from the note's assistant menu
///     (prompt generation runs on a text-bearing entry — audio transcript or
///     typed note — with the task pulled in as context; there is no
///     "Generate…" control on the task's own header),
///  3. wait for the GeneratedPromptCard to render,
///  4. expand the full prompt and scroll through it SLOWLY on camera,
///  5. copy it to the clipboard.
///
/// The LLM call itself is mocked deterministically (fixed two-section
/// markdown response, short realistic latency) by overriding
/// `cloudInferenceRepositoryProvider` — mirrors `task_cover_art`'s approach
/// to `generateImage`, and keeps nightly-build output byte-for-byte
/// reproducible instead of depending on live model output. Everything else
/// (skill modal, profile resolution, prompt building, streaming collection,
/// card rendering) is the real product pipeline
/// (`SkillInferenceRunner.runPromptGeneration`).
@Tags(['tutorial-video'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/tasks_tab_page.dart';
import 'package:lotti/features/tasks/ui/widgets/task_action_bar.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../test/helpers/manual_screenshot_locale.dart';
import '../manual_screenshot_utils.dart';
import 'tutorial_harness.dart';

const _providerId = 'tutorial-prompt-provider';
const _thinkingModelId = 'tutorial-prompt-thinking-model';
const _profileId = 'tutorial-prompt-profile';

/// Deterministic prompt "generation": returns a fixed, realistic two-section
/// markdown response after a short delay — long enough that the "generating"
/// state is visible on camera, short enough to keep the build fast.
class _FakeCloudInferenceRepository extends CloudInferenceRepository {
  _FakeCloudInferenceRepository(this._response, super.ref);

  final String _response;

  @override
  Stream<CreateChatCompletionStreamResponse> generate(
    String prompt, {
    required String model,
    required double? temperature,
    required String baseUrl,
    required String apiKey,
    String? systemMessage,
    int? maxCompletionTokens,
    OpenAIClient? overrideClient,
    AiConfigInferenceProvider? provider,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    GeminiThinkingMode? geminiThinkingMode,
    ReasoningEffort? reasoningEffort,
    InferenceImpactCollector? impactCollector,
  }) {
    return Stream<CreateChatCompletionStreamResponse>.fromFuture(
      Future<CreateChatCompletionStreamResponse>.delayed(
        const Duration(seconds: 3),
        () => CreateChatCompletionStreamResponse(
          id: 'tutorial-prompt-response',
          choices: [
            ChatCompletionStreamResponseChoice(
              delta: ChatCompletionStreamResponseDelta(content: _response),
              index: 0,
            ),
          ],
          object: 'chat.completion.chunk',
          created: 0,
        ),
      ),
    );
  }
}

const _fakeGeneratedPromptEn = '''
## Summary
A prompt for refactoring the penguin habitat telemetry service from a sequential polling loop into an event-driven pipeline with batched sensor reads and message-bus updates.

## Prompt
You are helping refactor the telemetry service in the penguin habitat monitoring system.

**Background**
The current implementation polls every sensor sequentially in a tight loop, which blocks the feeding scheduler whenever a poll cycle takes longer than expected. This creates cascading delays across the whole habitat automation stack, most visibly on the zero-gravity feeder integration described in the "Requirements" checklist below.

**Current task**
Refactor the telemetry service into an event-driven pipeline:
- Batch the sensor reads into a single poll cycle instead of firing one round-trip per sensor.
- Publish updates over the existing message bus rather than blocking callers on a synchronous read.
- Keep the public API backwards compatible so downstream consumers (including the feeding scheduler) do not need to change.
- Add latency tracing so mission control can diagnose spikes after the refactor ships.

**Requirements checklist**
- [ ] Batch sensor reads into one poll cycle
- [ ] Publish updates on the message bus
- [ ] Keep the public API backwards compatible
- [ ] Add latency tracing for mission control

**Constraints**
- Must not regress the zero-gravity feeder integration, which depends on low-latency reads during feeding windows.
- The public API surface (method signatures, return types) must remain unchanged; only the internal implementation should move to an event-driven model.
- Tracing spans should be tagged with the originating sensor id so mission control can correlate a spike back to a specific unit.

**Deliverable**
Provide the refactored service implementation, a brief migration note describing how existing callers are affected (if at all), and a short list of the new tracing spans you added.''';

// Section headers stay in English ("## Summary" / "## Prompt") even in the
// German build — GeneratedPromptCard's parsing regex matches those literal
// English words regardless of locale (matching the real skill's own system
// instructions, which always specify English headers with a
// locale-appropriate body). A translated heading here would fail the regex
// and silently fall back to "first line as summary".
const _fakeGeneratedPromptDe = '''
## Summary
Ein Prompt zur Refaktorisierung des Telemetrie-Dienstes im Pinguin-Habitat von einer sequenziellen Abfrageschleife zu einer ereignisgesteuerten Pipeline mit gebündelten Sensor-Reads und Message-Bus-Updates.

## Prompt
Du hilfst dabei, den Telemetrie-Dienst im Überwachungssystem des Pinguin-Habitats zu refaktorisieren.

**Hintergrund**
Die aktuelle Implementierung fragt alle Sensoren sequenziell in einer engen Schleife ab, was den Fütterungsplan blockiert, sobald ein Abfragezyklus länger dauert als erwartet. Das erzeugt kaskadierende Verzögerungen im gesamten Habitat-Automatisierungsstack, am deutlichsten bei der Integration des Schwerelosigkeits-Futterautomaten aus der Checkliste "Anforderungen" unten.

**Aktuelle Aufgabe**
Refaktorisiere den Telemetrie-Dienst zu einer ereignisgesteuerten Pipeline:
- Bündle die Sensor-Reads in einem einzigen Abfragezyklus, statt für jeden Sensor einen eigenen Roundtrip zu senden.
- Veröffentliche Updates über den vorhandenen Message-Bus, statt Aufrufer mit einem synchronen Read zu blockieren.
- Halte die öffentliche API abwärtskompatibel, damit nachgelagerte Konsumenten (einschließlich des Fütterungsplans) nicht angepasst werden müssen.
- Ergänze Latenz-Tracing, damit die Missionszentrale Spitzen nach dem Refactoring diagnostizieren kann.

**Checkliste Anforderungen**
- [ ] Sensor-Reads in einen Poll-Zyklus bündeln
- [ ] Updates über den Message-Bus veröffentlichen
- [ ] Öffentliche API abwärtskompatibel halten
- [ ] Latenz-Tracing für die Missionszentrale ergänzen

**Randbedingungen**
- Die Integration des Schwerelosigkeits-Futterautomaten darf nicht regressieren, da sie während der Fütterungsfenster auf Reads mit niedriger Latenz angewiesen ist.
- Die öffentliche API-Oberfläche (Methodensignaturen, Rückgabetypen) muss unverändert bleiben; nur die interne Implementierung soll auf ein ereignisgesteuertes Modell umgestellt werden.
- Tracing-Spans sollten mit der ursprünglichen Sensor-ID getaggt werden, damit die Missionszentrale eine Spitze auf eine bestimmte Einheit zurückführen kann.

**Ergebnis**
Liefere die refaktorisierte Dienst-Implementierung, einen kurzen Migrationshinweis dazu, wie bestehende Aufrufer betroffen sind (falls überhaupt), und eine kurze Liste der neu hinzugefügten Tracing-Spans.''';

const _fakeGeneratedPromptFr = '''
## Summary
Un prompt pour refactoriser le service de télémétrie de l'habitat des pingouins d'une boucle d'interrogation séquentielle vers un pipeline événementiel avec regroupement des lectures de capteurs et mises à jour par bus de messages.

## Prompt
Tu aides à refactoriser le service de télémétrie dans le système de surveillance de l'habitat des pingouins.

**Contexte**
L'implémentation actuelle interroge tous les capteurs séquentiellement dans une boucle serrée, ce qui bloque le planificateur d'alimentation dès qu'un cycle d'interrogation prend plus de temps que prévu. Cela crée des retards en cascade dans toute la pile d'automatisation de l'habitat, le plus visiblement sur l'intégration du distributeur de nourriture en apesanteur décrite dans la checklist « Exigences » ci-dessous.

**Tâche actuelle**
Refactorise le service de télémétrie en un pipeline événementiel avec regroupement des lectures de capteurs :
- Regroupe les lectures de capteurs en un seul cycle d'interrogation au lieu de lancer un aller-retour par capteur.
- Publie les mises à jour sur le bus de messages existant plutôt que de bloquer les appelants sur une lecture synchrone.
- Garde l'API publique rétrocompatible pour que les consommateurs en aval (y compris le planificateur d'alimentation) n'aient pas besoin de changer.
- Ajoute le traçage de latence pour que le centre de contrôle puisse diagnostiquer les pics après la mise en production.

**Checklist Exigences**
- [ ] Regrouper les lectures de capteurs en un seul cycle d'interrogation
- [ ] Publier les mises à jour sur le bus de messages
- [ ] Garder l'API publique rétrocompatible
- [ ] Ajouter le traçage de latence pour le centre de contrôle

**Contraintes**
- Ne doit pas régresser l'intégration du distributeur de nourriture en apesanteur, qui dépend de lectures à faible latence pendant les fenêtres d'alimentation.
- La surface de l'API publique (signatures de méthodes, types de retour) doit rester inchangée ; seule l'implémentation interne doit passer à un modèle événementiel.
- Les spans de traçage doivent être étiquetés avec l'id du capteur d'origine pour que le centre de contrôle puisse relier un pic à une unité précise.

**Livrable**
Fournis l'implémentation refactorisée du service, une brève note de migration décrivant comment les appelants existants sont affectés (le cas échéant), et une courte liste des nouveaux spans de traçage ajoutés.''';

const _fakeGeneratedPromptIt = '''
## Summary
Un prompt per rifattorizzare il servizio di telemetria dell'habitat dei pinguini da un ciclo di polling sequenziale a una pipeline basata su eventi con letture dei sensori raggruppate e aggiornamenti tramite bus di messaggi.

## Prompt
Stai aiutando a rifattorizzare il servizio di telemetria nel sistema di monitoraggio dell'habitat dei pinguini.

**Contesto**
L'implementazione attuale interroga tutti i sensori in sequenza in un ciclo stretto, il che blocca il pianificatore dell'alimentazione ogni volta che un ciclo di polling richiede più tempo del previsto. Questo crea ritardi a cascata in tutto lo stack di automazione dell'habitat, più visibilmente nell'integrazione del distributore di cibo a gravità zero descritta nella checklist "Requisiti" qui sotto.

**Attività corrente**
Rifattorizza il servizio di telemetria in una pipeline basata su eventi con letture dei sensori raggruppate:
- Raggruppa le letture dei sensori in un unico ciclo di polling invece di avviare un round-trip per ogni sensore.
- Pubblica gli aggiornamenti sul bus di messaggi esistente invece di bloccare i chiamanti su una lettura sincrona.
- Mantieni l'API pubblica retrocompatibile in modo che i consumatori a valle (incluso il pianificatore dell'alimentazione) non debbano cambiare.
- Aggiungi il tracing della latenza in modo che il centro di controllo possa diagnosticare i picchi dopo il rilascio del refactoring.

**Checklist Requisiti**
- [ ] Raggruppare le letture dei sensori in un unico ciclo di polling
- [ ] Pubblicare gli aggiornamenti sul bus di messaggi
- [ ] Mantenere l'API pubblica retrocompatibile
- [ ] Aggiungere il tracing della latenza per il centro di controllo

**Vincoli**
- Non deve regredire l'integrazione del distributore di cibo a gravità zero, che dipende da letture a bassa latenza durante le finestre di alimentazione.
- La superficie dell'API pubblica (firme dei metodi, tipi di ritorno) deve rimanere invariata; solo l'implementazione interna deve passare a un modello basato su eventi.
- Gli span di tracing dovrebbero essere taggati con l'id del sensore di origine in modo che il centro di controllo possa correlare un picco a un'unità specifica.

**Risultato**
Fornisci l'implementazione rifattorizzata del servizio, una breve nota di migrazione che descrive come sono interessati i chiamanti esistenti (se lo sono), e un breve elenco dei nuovi span di tracing aggiunti.''';

const _fakeGeneratedPromptEs = '''
## Summary
Un prompt para refactorizar el servicio de telemetría del hábitat de pingüinos de un bucle de sondeo secuencial a un pipeline basado en eventos con lecturas de sensores agrupadas y actualizaciones por bus de mensajes.

## Prompt
Estás ayudando a refactorizar el servicio de telemetría en el sistema de monitorización del hábitat de pingüinos.

**Contexto**
La implementación actual consulta todos los sensores de forma secuencial en un bucle cerrado, lo que bloquea el planificador de alimentación cada vez que un ciclo de sondeo tarda más de lo esperado. Esto crea retrasos en cascada en toda la pila de automatización del hábitat, de forma más visible en la integración del comedero de gravedad cero descrita en la checklist "Requisitos" a continuación.

**Tarea actual**
Refactoriza el servicio de telemetría en un pipeline basado en eventos con lecturas de sensores agrupadas:
- Agrupa las lecturas de los sensores en un solo ciclo de sondeo en lugar de lanzar un viaje de ida y vuelta por sensor.
- Publica las actualizaciones en el bus de mensajes existente en lugar de bloquear a los llamadores con una lectura síncrona.
- Mantén la API pública compatible con versiones anteriores para que los consumidores posteriores (incluido el planificador de alimentación) no necesiten cambiar.
- Añade trazas de latencia para que el centro de control pueda diagnosticar picos tras el despliegue.

**Checklist de Requisitos**
- [ ] Agrupar las lecturas de los sensores en un solo ciclo de sondeo
- [ ] Publicar las actualizaciones en el bus de mensajes
- [ ] Mantener la API pública compatible con versiones anteriores
- [ ] Añadir trazas de latencia para el centro de control

**Restricciones**
- No debe afectar negativamente a la integración del comedero de gravedad cero, que depende de lecturas de baja latencia durante las ventanas de alimentación.
- La superficie de la API pública (firmas de métodos, tipos de retorno) debe permanecer sin cambios; solo la implementación interna debe pasar a un modelo basado en eventos.
- Los spans de traza deben etiquetarse con el id del sensor de origen para que el centro de control pueda correlacionar un pico con una unidad concreta.

**Entregable**
Proporciona la implementación refactorizada del servicio, una breve nota de migración que describa cómo se ven afectados los llamadores existentes (si es el caso), y una breve lista de los nuevos spans de traza añadidos.''';

const _fakeGeneratedPromptCs = '''
## Summary
Prompt pro refaktorování telemetrické služby pinguiního habitatu ze sekvenční dotazovací smyčky na pipeline řízenou událostmi se seskupenými čteními senzorů a aktualizacemi přes sběrnici zpráv.

## Prompt
Pomáháš refaktorovat telemetrickou službu v monitorovacím systému habitatu tučňáků.

**Pozadí**
Současná implementace dotazuje všechny senzory sekvenčně v těsné smyčce, což blokuje plánovač krmení, kdykoli dotazovací cyklus trvá déle, než se očekávalo. To vytváří kaskádová zpoždění napříč celým automatizačním stackem habitatu, nejviditelněji na integraci beztížné krmítko popsané v checklistu "Požadavky" níže.

**Aktuální úkol**
Refaktoruj telemetrickou službu na pipeline řízenou událostmi se seskupenými čteními senzorů:
- Seskup čtení senzorů do jednoho dotazovacího cyklu místo jednoho round-tripu na senzor.
- Publikuj aktualizace přes stávající sběrnici zpráv místo blokování volajících synchronním čtením.
- Zachovej zpětnou kompatibilitu veřejného API, aby navazující konzumenti (včetně plánovače krmení) nemuseli měnit svůj kód.
- Přidej trasování latence, aby řídicí středisko mohlo po nasazení refaktoringu diagnostikovat výpadky.

**Checklist Požadavky**
- [ ] Seskupit čtení senzorů do jednoho dotazovacího cyklu
- [ ] Publikovat aktualizace na sběrnici zpráv
- [ ] Zachovat zpětnou kompatibilitu veřejného API
- [ ] Přidat trasování latence pro řídicí středisko

**Omezení**
- Nesmí dojít k regresi integrace beztížné krmítko, která závisí na čteních s nízkou latencí během krmných oken.
- Povrch veřejného API (signatury metod, návratové typy) musí zůstat beze změny; na model řízený událostmi se má přesunout jen vnitřní implementace.
- Trasovací spany by měly být označeny id původního senzoru, aby řídicí středisko mohlo výpadek přiřadit ke konkrétní jednotce.

**Výstup**
Dodej refaktorovanou implementaci služby, stručnou poznámku k migraci popisující, jak jsou ovlivněni stávající volající (pokud vůbec), a krátký seznam nově přidaných trasovacích spanů.''';

const _fakeGeneratedPromptNl = '''
## Summary
Een prompt om de telemetrieservice van het pinguïnhabitat te refactoren van een sequentiële pollinglus naar een gebeurtenisgestuurde pipeline met gebundelde sensormetingen en updates via de berichtenbus.

## Prompt
Je helpt bij het refactoren van de telemetrieservice in het monitoringsysteem van het pinguïnhabitat.

**Achtergrond**
De huidige implementatie bevraagt alle sensoren achtereenvolgens in een strakke lus, wat de voederplanner blokkeert zodra een pollingcyclus langer duurt dan verwacht. Dit veroorzaakt cascaderende vertragingen door de hele automatiseringsstack van het habitat, het duidelijkst zichtbaar bij de integratie van de zwaartekrachtloze voederautomaat die hieronder in de checklist "Vereisten" wordt beschreven.

**Huidige taak**
Refactor de telemetrieservice naar een gebeurtenisgestuurde pipeline met gebundelde sensormetingen:
- Bundel de sensormetingen in één pollingcyclus in plaats van één round-trip per sensor.
- Publiceer updates via de bestaande berichtenbus in plaats van aanroepers te blokkeren met een synchrone lezing.
- Houd de publieke API achterwaarts compatibel zodat downstream-consumenten (inclusief de voederplanner) niets hoeven te wijzigen.
- Voeg latentietracing toe zodat het missiecentrum na de refactor pieken kan diagnosticeren.

**Checklist Vereisten**
- [ ] Sensormetingen bundelen in één pollingcyclus
- [ ] Updates publiceren op de berichtenbus
- [ ] De publieke API achterwaarts compatibel houden
- [ ] Latentietracing toevoegen voor het missiecentrum

**Beperkingen**
- Mag de integratie van de zwaartekrachtloze voederautomaat niet laten regresseren, die afhankelijk is van laag-latente metingen tijdens voederperiodes.
- Het publieke API-oppervlak (methodesignaturen, retourtypes) moet ongewijzigd blijven; alleen de interne implementatie mag naar een gebeurtenisgestuurd model verschuiven.
- Tracingspans moeten worden getagd met het originele sensor-id zodat het missiecentrum een piek kan herleiden tot een specifieke unit.

**Op te leveren**
Lever de gerefactorde service-implementatie, een korte migratienotitie die beschrijft hoe bestaande aanroepers worden beïnvloed (indien van toepassing), en een korte lijst van de nieuw toegevoegde tracingspans.''';

const _fakeGeneratedPromptRo = '''
## Summary
Un prompt pentru refactorizarea serviciului de telemetrie al habitatului pinguinilor dintr-o buclă de interogare secvențială într-un pipeline bazat pe evenimente cu citiri ale senzorilor grupate și actualizări prin magistrala de mesaje.

## Prompt
Ajuți la refactorizarea serviciului de telemetrie din sistemul de monitorizare al habitatului pinguinilor.

**Context**
Implementarea actuală interoghează toți senzorii secvențial într-o buclă strânsă, ceea ce blochează planificatorul de hrănire ori de câte ori un ciclu de interogare durează mai mult decât se aștepta. Acest lucru creează întârzieri în cascadă în întregul stack de automatizare al habitatului, cel mai vizibil în integrarea hrănitorul cu gravitație zero descrisă în lista de verificare „Cerințe" de mai jos.

**Sarcina curentă**
Refactorizați serviciul de telemetrie într-un pipeline bazat pe evenimente cu citiri ale senzorilor grupate:
- Grupați citirile senzorilor într-un singur ciclu de interogare în loc să inițiați un round-trip pentru fiecare senzor.
- Publicați actualizările pe magistrala de mesaje existentă în loc să blocați apelanții cu o citire sincronă.
- Păstrați API-ul public compatibil cu versiunile anterioare, astfel încât consumatorii din aval (inclusiv planificatorul de hrănire) să nu fie nevoiți să se schimbe.
- Adăugați urmărirea latenței, astfel încât centrul de control al misiunii să poată diagnostica vârfurile după lansarea refactorizării.

**Lista de verificare Cerințe**
- [ ] Grupați citirile senzorilor într-un singur ciclu de interogare
- [ ] Publicați actualizările pe magistrala de mesaje
- [ ] Păstrați API-ul public compatibil cu versiunile anterioare
- [ ] Adăugați urmărirea latenței pentru centrul de control al misiunii

**Constrângeri**
- Nu trebuie să regreseze integrarea hrănitorul cu gravitație zero, care depinde de citiri cu latență redusă în timpul ferestrelor de hrănire.
- Suprafața API-ului public (semnăturile metodelor, tipurile de returnare) trebuie să rămână neschimbată; doar implementarea internă ar trebui să treacă la un model bazat pe evenimente.
- Span-urile de urmărire ar trebui etichetate cu id-ul senzorului de origine, astfel încât centrul de control al misiunii să poată corela un vârf cu o unitate specifică.

**Livrabil**
Furnizați implementarea refactorizată a serviciului, o scurtă notă de migrare care descrie modul în care sunt afectați apelanții existenți (dacă este cazul) și o listă scurtă a noilor span-uri de urmărire adăugate.''';

const _fakeGeneratedPromptPt = '''
## Summary
Um prompt para refatorar o serviço de telemetria do habitat dos pinguins de um loop de polling sequencial para um pipeline orientado a eventos com leituras de sensores agrupadas e atualizações via barramento de mensagens.

## Prompt
Você está ajudando a refatorar o serviço de telemetria no sistema de monitoramento do habitat dos pinguins.

**Contexto**
A implementação atual consulta todos os sensores sequencialmente em um loop apertado, o que bloqueia o agendador de alimentação sempre que um ciclo de polling demora mais do que o esperado. Isso cria atrasos em cascata em toda a pilha de automação do habitat, mais visivelmente na integração do alimentador de gravidade zero descrita na checklist "Requisitos" abaixo.

**Tarefa atual**
Refatore o serviço de telemetria para um pipeline orientado a eventos com leituras de sensores agrupadas:
- Agrupe as leituras dos sensores em um único ciclo de polling em vez de disparar uma ida e volta por sensor.
- Publique atualizações no barramento de mensagens existente em vez de bloquear os chamadores com uma leitura síncrona.
- Mantenha a API pública compatível com versões anteriores para que os consumidores downstream (incluindo o agendador de alimentação) não precisem mudar.
- Adicione rastreamento de latência para que o centro de controle possa diagnosticar picos após o lançamento do refactor.

**Checklist Requisitos**
- [ ] Agrupar as leituras dos sensores em um único ciclo de polling
- [ ] Publicar atualizações no barramento de mensagens
- [ ] Manter a API pública compatível com versões anteriores
- [ ] Adicionar rastreamento de latência para o centro de controle

**Restrições**
- Não deve regredir a integração do alimentador de gravidade zero, que depende de leituras de baixa latência durante as janelas de alimentação.
- A superfície da API pública (assinaturas de métodos, tipos de retorno) deve permanecer inalterada; apenas a implementação interna deve migrar para um modelo orientado a eventos.
- Os spans de rastreamento devem ser marcados com o id do sensor de origem para que o centro de controle possa correlacionar um pico a uma unidade específica.

**Entregável**
Forneça a implementação refatorada do serviço, uma breve nota de migração descrevendo como os chamadores existentes são afetados (se houver) e uma lista curta dos novos spans de rastreamento adicionados.''';

const _fakeGeneratedPromptDa = '''
## Summary
En prompt til at refaktorere pingvinhabitatets telemetritjeneste fra en sekventiel polling-loop til en begivenhedsdrevet pipeline med samlede sensoraflæsninger og opdateringer via beskedbussen.

## Prompt
Du hjælper med at refaktorere telemetritjenesten i pingvinhabitatets overvågningssystem.

**Baggrund**
Den nuværende implementering forespørger alle sensorer sekventielt i en tæt løkke, hvilket blokerer foderplanlæggeren, når en polling-cyklus tager længere tid end forventet. Dette skaber kaskadeforsinkelser i hele habitatets automatiseringsstack, mest synligt i integrationen med vægtløs foderautomat, som er beskrevet i tjeklisten "Krav" nedenfor.

**Nuværende opgave**
Refaktorer telemetritjenesten til en begivenhedsdrevet pipeline med samlede sensoraflæsninger:
- Saml sensoraflæsningerne i én polling-cyklus i stedet for én tur-retur pr. sensor.
- Udgiv opdateringer via den eksisterende beskedbus i stedet for at blokere kaldere med en synkron læsning.
- Hold den offentlige API bagudkompatibel, så downstream-forbrugere (inklusive foderplanlæggeren) ikke behøver at ændre sig.
- Tilføj latenssporing, så kontrolcentret kan diagnosticere spidsbelastninger efter udrulningen.

**Tjekliste Krav**
- [ ] Saml sensoraflæsninger i én polling-cyklus
- [ ] Udgiv opdateringer på beskedbussen
- [ ] Hold den offentlige API bagudkompatibel
- [ ] Tilføj latenssporing til kontrolcentret

**Begrænsninger**
- Må ikke forringe integrationen med vægtløs foderautomat, som er afhængig af lav-latens-aflæsninger under fodringsvinduer.
- Den offentlige API-overflade (metodesignaturer, returtyper) skal forblive uændret; kun den interne implementering bør flyttes til en begivenhedsdrevet model.
- Sporingsspænd bør tagges med det oprindelige sensor-id, så kontrolcentret kan korrelere en spidsbelastning tilbage til en bestemt enhed.

**Leverance**
Lever den refaktorerede serviceimplementering, en kort migreringsnote, der beskriver, hvordan eksisterende kaldere påvirkes (om overhovedet), og en kort liste over de nye sporingsspænd, du har tilføjet.''';

const _fakeGeneratedPromptSv = '''
## Summary
En prompt för att refaktorera pingvinhabitatets telemetritjänst från en sekventiell pollningsloop till en händelsestyrd pipeline med batchade sensoravläsningar och uppdateringar via meddelandebussen.

## Prompt
Du hjälper till att refaktorera telemetritjänsten i pingvinhabitatets övervakningssystem.

**Bakgrund**
Den nuvarande implementationen frågar av alla sensorer sekventiellt i en tät loop, vilket blockerar matningsschemaläggaren närhelst en pollningscykel tar längre tid än förväntat. Detta skapar kaskaderande fördröjningar i hela habitatets automationsstack, mest synligt i integrationen med viktlös matningsautomat som beskrivs i checklistan "Krav" nedan.

**Aktuell uppgift**
Refaktorera telemetritjänsten till en händelsestyrd pipeline med batchade sensoravläsningar:
- Samla sensoravläsningarna i en enda pollningscykel istället för en rundtur per sensor.
- Publicera uppdateringar på den befintliga meddelandebussen istället för att blockera anropare med en synkron läsning.
- Håll det publika API:et bakåtkompatibelt så att nedströms konsumenter (inklusive matningsschemaläggaren) inte behöver ändras.
- Lägg till latensspårning så att kontrollcentralen kan diagnostisera toppar efter att refaktoreringen har lanserats.

**Checklista Krav**
- [ ] Samla sensoravläsningar i en enda pollningscykel
- [ ] Publicera uppdateringar på meddelandebussen
- [ ] Håll det publika API:et bakåtkompatibelt
- [ ] Lägg till latensspårning för kontrollcentralen

**Begränsningar**
- Får inte försämra integrationen med viktlös matningsautomat, som är beroende av lågfördröjda avläsningar under matningsfönster.
- Den publika API-ytan (metodsignaturer, returtyper) måste förbli oförändrad; endast den interna implementationen bör flyttas till en händelsestyrd modell.
- Spårningsspann bör taggas med det ursprungliga sensor-id:t så att kontrollcentralen kan korrelera en topp till en specifik enhet.

**Leverabel**
Leverera den refaktorerade tjänsteimplementationen, en kort migreringsanteckning som beskriver hur befintliga anropare påverkas (om alls), och en kort lista över de nya spårningsspann du lagt till.''';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final manifest = TutorialManifest.fromEnvironment();
  final locale = manualScreenshotLocaleFromEnvironment(Platform.environment);
  String localized({
    required String en,
    required String de,
    String? fr,
    String? it,
    String? es,
    String? cs,
    String? nl,
    String? ro,
    String? pt,
    String? da,
    String? sv,
  }) => manualScreenshotText(
    en: en,
    de: de,
    fr: fr,
    it: it,
    es: es,
    cs: cs,
    nl: nl,
    ro: ro,
    pt: pt,
    da: da,
    sv: sv,
  );

  testWidgets(
    'drives the task-coding-prompt tutorial flow',
    (tester) async {
      tester.platformDispatcher.localeTestValue = locale;
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final harness = await TutorialAppHarness.setUp(
        aiConfigs: _promptConfigs(),
        languageCode: locale.languageCode,
        categoryTransform: (category) =>
            category.copyWith(defaultProfileId: _profileId),
      );
      addTearDown(harness.dispose);

      final taskTitle = localized(
        en: 'Refactor the habitat telemetry service',
        de: 'Habitat-Telemetrie-Dienst refaktorisieren',
        fr: '''Refactoriser le service de télémétrie de l'habitat''',
        it: '''Rifattorizza il servizio di telemetria dell'habitat''',
        es: '''Refactoriza el servicio de telemetría del hábitat''',
        cs: '''Refaktoruj telemetrickou službu habitatu''',
        nl: '''Refactor de telemetrieservice van het habitat''',
        ro: '''Refactorizați serviciul de telemetrie al habitatului''',
        pt: '''Refatore o serviço de telemetria do habitat''',
        da: '''Refaktorer habitatets telemetritjeneste''',
        sv: '''Refaktorera habitatets telemetritjänst''',
      );
      final task = await harness.persistenceLogic.createTaskEntry(
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.inProgress(
            id: 'tutorial-prompt-task-status',
            createdAt: DateTime.now(),
            utcOffset: DateTime.now().timeZoneOffset.inMinutes,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
          // ProfileAutomationResolver.resolveForTask reads task.data.profileId
          // directly — it does NOT fall back to category.defaultProfileId.
          // Without this, the skill trigger silently no-ops (no profile
          // configured) and the picker/progress flow never produces a result.
          profileId: _profileId,
        ),
        entryText: EntryText(
          plainText: localized(
            en:
                'The telemetry service in the penguin habitat polls every '
                'sensor sequentially and blocks the feeding scheduler. '
                'Refactor it to an event-driven pipeline: batch the sensor '
                'reads, push updates over the existing message bus, and '
                'keep the public API backwards compatible. Mind the '
                'zero-gravity feeder integration and add tracing so '
                'mission control can debug latency spikes.',
            fr: '''Le service de télémétrie de l'habitat des pingouins interroge chaque capteur de manière séquentielle et bloque le planificateur d'alimentation. Refactorise-le en un pipeline événementiel : regroupe les lectures de capteurs, publie les mises à jour sur le bus de messages existant, et garde l'API publique rétrocompatible. Prends en compte l'intégration du distributeur de nourriture en apesanteur et ajoute du traçage pour que le centre de contrôle puisse déboguer les pics de latence.''',
            it: '''Il servizio di telemetria nell'habitat dei pinguini interroga ogni sensore in sequenza e blocca il pianificatore dell'alimentazione. Rifattorizzalo in una pipeline basata su eventi: raggruppa le letture dei sensori, pubblica gli aggiornamenti sul bus di messaggi esistente e mantieni l'API pubblica retrocompatibile. Tieni conto dell'integrazione del distributore di cibo a gravità zero e aggiungi il tracing affinché il centro di controllo possa diagnosticare i picchi di latenza.''',
            es: '''El servicio de telemetría del hábitat de pingüinos consulta cada sensor de forma secuencial y bloquea el planificador de alimentación. Refactorízalo en un pipeline basado en eventos: agrupa las lecturas de los sensores, publica las actualizaciones en el bus de mensajes existente y mantén la API pública compatible con versiones anteriores. Ten en cuenta la integración del comedero de gravedad cero y añade trazas para que el centro de control pueda depurar los picos de latencia.''',
            cs: '''Telemetrická služba v pinguiním habitatu dotazuje všechny senzory postupně a blokuje plánovač krmení. Refaktoruj ji na pipeline řízenou událostmi: seskup čtení senzorů, publikuj aktualizace přes stávající sběrnici zpráv a zachovej zpětnou kompatibilitu veřejného API. Mysli na integraci beztížného krmítka a přidej trasování, aby řídicí středisko mohlo ladit výpadky latence.''',
            nl: '''De telemetrieservice in het pinguïnhabitat bevraagt elke sensor achtereenvolgens en blokkeert de voederplanner. Refactor het naar een gebeurtenisgestuurde pipeline: bundel de sensormetingen, publiceer updates via de bestaande berichtenbus en houd de publieke API achterwaarts compatibel. Houd rekening met de integratie van de zwaartekrachtloze voederautomaat en voeg tracing toe zodat het missiecentrum latentiepieken kan debuggen.''',
            ro: '''Serviciul de telemetrie din habitatul pinguinilor interoghează fiecare senzor secvențial și blochează planificatorul de hrănire. Refactorizați-l într-un pipeline bazat pe evenimente: grupați citirile senzorilor, publicați actualizările pe magistrala de mesaje existentă și păstrați API-ul public compatibil cu versiunile anterioare. Aveți în vedere integrarea hrănitorului cu gravitație zero și adăugați urmărire pentru ca centrul de control al misiunii să poată depana vârfurile de latență.''',
            pt: '''O serviço de telemetria no habitat dos pinguins consulta cada sensor sequencialmente e bloqueia o agendador de alimentação. Refatore-o para um pipeline orientado a eventos: agrupe as leituras dos sensores, publique atualizações no barramento de mensagens existente e mantenha a API pública compatível com versões anteriores. Considere a integração do alimentador de gravidade zero e adicione rastreamento para que o centro de controle possa depurar picos de latência.''',
            da: '''Telemetritjenesten i pingvinhabitatet forespørger hver sensor sekventielt og blokerer foderplanlæggeren. Refaktorer den til en begivenhedsdrevet pipeline: saml sensoraflæsningerne, udgiv opdateringer via den eksisterende beskedbus, og hold den offentlige API bagudkompatibel. Husk integrationen med den vægtløse foderautomat, og tilføj sporing, så kontrolcentret kan fejlfinde latenstoppe.''',
            sv: '''Telemetritjänsten i pingvinhabitatet frågar av varje sensor sekventiellt och blockerar matningsschemaläggaren. Refaktorera den till en händelsestyrd pipeline: samla sensoravläsningarna i batchar, publicera uppdateringar på den befintliga meddelandebussen och håll det publika API:et bakåtkompatibelt. Tänk på integrationen med den viktlösa matningsautomaten och lägg till spårning så att kontrollcentralen kan felsöka latensspikar.''',
            de:
                'Der Telemetrie-Dienst im Pinguin-Habitat fragt alle '
                'Sensoren sequenziell ab und blockiert den Fütterungsplan. '
                'Refaktorisiere ihn zu einer ereignisgesteuerten Pipeline: '
                'bündle die Sensor-Reads, schicke Updates über den '
                'vorhandenen Message-Bus und halte die öffentliche API '
                'abwärtskompatibel. Beachte die Integration des '
                'Schwerelosigkeits-Futterautomaten und ergänze Tracing, '
                'damit die Missionszentrale Latenzspitzen debuggen kann.',
          ),
        ),
        categoryId: harness.world.category.id,
      );
      expect(task, isNotNull);
      await ChecklistRepository().createChecklist(
        taskId: task!.meta.id,
        title: localized(
          en: 'Requirements',
          de: 'Anforderungen',
          fr: '''Exigences''',
          it: '''Requisiti''',
          es: '''Requisitos''',
          cs: '''Požadavky''',
          nl: '''Vereisten''',
          ro: '''Cerințe''',
          pt: '''Requisitos''',
          da: '''Krav''',
          sv: '''Krav''',
        ),
        items: [
          ChecklistItemData(
            title: localized(
              en: 'Batch sensor reads into one poll cycle',
              de: 'Sensor-Reads in einen Poll-Zyklus bündeln',
              fr: '''Regrouper les lectures de capteurs en un seul cycle d'interrogation''',
              it: '''Raggruppare le letture dei sensori in un unico ciclo di polling''',
              es: '''Agrupar las lecturas de los sensores en un solo ciclo de sondeo''',
              cs: '''Seskupit čtení senzorů do jednoho dotazovacího cyklu''',
              nl: '''Sensormetingen bundelen in één pollingcyclus''',
              ro: '''Grupați citirile senzorilor într-un singur ciclu de interogare''',
              pt: '''Agrupar as leituras dos sensores em um único ciclo de polling''',
              da: '''Saml sensoraflæsninger i én polling-cyklus''',
              sv: '''Samla sensoravläsningar i en enda pollningscykel''',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Publish updates on the message bus',
              de: 'Updates über den Message-Bus veröffentlichen',
              fr: '''Publier les mises à jour sur le bus de messages''',
              it: '''Pubblicare gli aggiornamenti sul bus di messaggi''',
              es: '''Publicar las actualizaciones en el bus de mensajes''',
              cs: '''Publikovat aktualizace na sběrnici zpráv''',
              nl: '''Updates publiceren op de berichtenbus''',
              ro: '''Publicați actualizările pe magistrala de mesaje''',
              pt: '''Publicar atualizações no barramento de mensagens''',
              da: '''Udgiv opdateringer på beskedbussen''',
              sv: '''Publicera uppdateringar på meddelandebussen''',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Keep the public API backwards compatible',
              de: 'Öffentliche API abwärtskompatibel halten',
              fr: '''Garder l'API publique rétrocompatible''',
              it: '''Mantenere l'API pubblica retrocompatibile''',
              es: '''Mantener la API pública compatible con versiones anteriores''',
              cs: '''Zachovat zpětnou kompatibilitu veřejného API''',
              nl: '''De publieke API achterwaarts compatibel houden''',
              ro: '''Păstrați API-ul public compatibil cu versiunile anterioare''',
              pt: '''Manter a API pública compatível com versões anteriores''',
              da: '''Hold den offentlige API bagudkompatibel''',
              sv: '''Håll det publika API:et bakåtkompatibelt''',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
          ChecklistItemData(
            title: localized(
              en: 'Add latency tracing for mission control',
              de: 'Latenz-Tracing für die Missionszentrale ergänzen',
              fr: '''Ajouter le traçage de latence pour le centre de contrôle''',
              it: '''Aggiungere il tracing della latenza per il centro di controllo''',
              es: '''Añadir trazas de latencia para el centro de control''',
              cs: '''Přidat trasování latence pro řídicí středisko''',
              nl: '''Latentietracing toevoegen voor het missiecentrum''',
              ro: '''Adăugați urmărirea latenței pentru centrul de control al misiunii''',
              pt: '''Adicionar rastreamento de latência para o centro de controle''',
              da: '''Tilføj latenssporing til kontrolcentret''',
              sv: '''Lägg till latensspårning för kontrollcentralen''',
            ),
            isChecked: false,
            linkedChecklists: const [],
          ),
        ],
      );

      // Prompt generation runs on a text-bearing entry (audio transcript or
      // typed note), not on the task itself — this linked voice note is what
      // the "Generate…" menu actually attaches to; `linkedFromId: task.id`
      // gives the skill its full-task context (checklist, description).
      // JournalAudio (not a typed JournalEntry note) — mirrors
      // task_cover_art's linked-note shape, which is proven to render
      // correctly in the task detail split pane.
      final situationTranscript = localized(
        en:
            'Just hit this in staging: the telemetry poll loop '
            'stalls for 4-6 seconds whenever more than a dozen '
            'sensors report at once, and the feeding scheduler '
            'queue backs up right behind it. Need a prompt I can '
            'hand to a coding assistant to fix this properly.',
        de:
            'Gerade in der Staging-Umgebung aufgefallen: Die '
            'Telemetrie-Abfrageschleife hängt 4 bis 6 Sekunden, '
            'sobald mehr als ein Dutzend Sensoren gleichzeitig '
            'melden, und die Fütterungsplan-Warteschlange staut '
            'sich direkt dahinter. Brauche einen Prompt für einen '
            'Coding-Assistenten, um das sauber zu beheben.',
        fr: '''Je viens de tomber là-dessus en staging : la boucle d'interrogation de télémétrie se bloque pendant 4 à 6 secondes dès que plus d'une douzaine de capteurs remontent en même temps, et la file du planificateur d'alimentation s'accumule juste derrière. J'ai besoin d'un prompt à donner à un assistant de code pour corriger ça correctement.''',
        it: '''L'ho appena trovato in staging: il ciclo di polling della telemetria si blocca per 4-6 secondi ogni volta che più di una dozzina di sensori segnalano contemporaneamente, e la coda del pianificatore dell'alimentazione si accumula subito dopo. Mi serve un prompt da dare a un assistente di coding per risolvere la cosa per bene.''',
        es: '''Me acabo de encontrar esto en staging: el bucle de sondeo de telemetría se bloquea de 4 a 6 segundos cada vez que más de una docena de sensores informan a la vez, y la cola del planificador de alimentación se acumula justo detrás. Necesito un prompt que darle a un asistente de programación para arreglar esto como es debido.''',
        cs: '''Právě jsem na to narazil ve stagingu: smyčka dotazování telemetrie se zasekne na 4 až 6 sekund, kdykoli nahlásí data najednou víc než tucet senzorů, a fronta plánovače krmení se hned za tím hromadí. Potřebuju prompt, který dám kódovacímu asistentovi, aby to pořádně opravil.''',
        nl: '''Ik ben hier net op gestuit in staging: de telemetrie-pollinglus hapert 4 tot 6 seconden zodra meer dan een dozijn sensoren tegelijk rapporteren, en de wachtrij van de voederplanner loopt daar direct achter vast. Ik heb een prompt nodig om aan een codeerassistent te geven om dit goed op te lossen.''',
        ro: '''Tocmai am dat peste asta în staging: bucla de interogare a telemetriei se blochează timp de 4-6 secunde de fiecare dată când raportează simultan mai mult de o duzină de senzori, iar coada planificatorului de hrănire se aglomerează chiar în spate. Am nevoie de un prompt pe care să-l dau unui asistent de programare ca să repare asta corect.''',
        pt: '''Acabei de encontrar isso em staging: o loop de polling da telemetria trava por 4 a 6 segundos sempre que mais de uma dezena de sensores reportam ao mesmo tempo, e a fila do agendador de alimentação se acumula logo atrás. Preciso de um prompt para dar a um assistente de código para corrigir isso direito.''',
        da: '''Stødte lige på dette i staging: telemetriens polling-loop går i stå i 4-6 sekunder, hver gang mere end et dusin sensorer rapporterer på samme tid, og foderplanlæggerens kø hober sig op lige bagefter. Har brug for en prompt, jeg kan give til en kodningsassistent for at rette det ordentligt.''',
        sv: '''Stötte just på det här i staging: telemetrins pollningsloop hakar upp sig i 4–6 sekunder varje gång fler än ett dussin sensorer rapporterar samtidigt, och matningsschemaläggarens kö hopar sig direkt bakom. Behöver en prompt jag kan ge till en kodningsassistent för att fixa det ordentligt.''',
      );
      final noteMeta = await harness.persistenceLogic.createMetadata();
      final situationNote = JournalEntity.journalAudio(
        meta: noteMeta.copyWith(categoryId: harness.world.category.id),
        // The real recorder writes a finished transcript into BOTH
        // data.transcripts and entryText (RecorderController's
        // _saveRealtimeTranscript) — the note's visible card only ever
        // renders entryText (via the note editor), never
        // AudioTranscript.transcript directly, so this is needed for the
        // transcript to actually show on screen.
        entryText: EntryText(
          plainText: situationTranscript,
          markdown: situationTranscript,
        ),
        data: AudioData(
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          audioFile: 'tutorial-prompt-note.m4a',
          audioDirectory: '/audio/tutorial/',
          duration: const Duration(seconds: 14),
          transcripts: [
            AudioTranscript(
              created: DateTime.now(),
              library: 'tutorial',
              model: 'voxtral-small-24b-2507',
              detectedLanguage: locale.languageCode,
              transcript: situationTranscript,
            ),
          ],
        ),
      );
      await harness.persistenceLogic.createDbEntity(
        situationNote,
        shouldAddGeolocation: false,
        enqueueSync: false,
        linkedId: task.id,
      );

      final fakeResponse = localized(
        en: _fakeGeneratedPromptEn,
        de: _fakeGeneratedPromptDe,
        fr: _fakeGeneratedPromptFr,
        it: _fakeGeneratedPromptIt,
        es: _fakeGeneratedPromptEs,
        cs: _fakeGeneratedPromptCs,
        nl: _fakeGeneratedPromptNl,
        ro: _fakeGeneratedPromptRo,
        pt: _fakeGeneratedPromptPt,
        da: _fakeGeneratedPromptDa,
        sv: _fakeGeneratedPromptSv,
      );

      final cursor = TutorialCursorController();
      final hudClock = ValueNotifier<Duration>(Duration.zero);
      addTearDown(hudClock.dispose);
      await tester.pumpWidget(
        manualScreenshotBoundary(
          child: TutorialCursorLayer(
            controller: cursor,
            elapsed: hudClock,
            child: ProviderScope(
              overrides: [
                ...harness.providerOverrides(),
                cloudInferenceRepositoryProvider.overrideWith(
                  (ref) => _FakeCloudInferenceRepository(fakeResponse, ref),
                ),
              ],
              child: MyBeamerApp(
                navService: harness.navService,
                userActivityService: harness.userActivityService,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Land on Tasks BEFORE the recorded timeline starts — the app's real
      // default landing tab is the Logbook (Journal), which would
      // otherwise flash on screen during the intro step's establishing
      // hold.
      harness.navService.setIndex(
        harness.navService.beamerDelegates.indexOf(
          harness.navService.tasksDelegate,
        ),
      );
      await tester.pump();

      // Give the task a real (non-dormant) agent — without this the AI
      // summary card only shows an "Assign agent" CTA for the whole video.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyBeamerApp)),
      );
      await container
          .read(taskAgentServiceProvider)
          .createTaskAgent(
            taskId: task.id,
            allowedCategoryIds: {harness.world.category.id},
            templateId: lauraTemplateId,
            profileId: _profileId,
          );

      final driver =
          TutorialDriver(
              tester: tester,
              manifest: manifest,
              cursor: cursor,
              hud: hudClock,
            )
            ..diagnostics = () {
              final nav = harness.navService;
              return 'currentPath=${nav.currentPath} '
                  'detailStack=${nav.desktopTaskDetailStack.value} '
                  'promptCards=${find.text('Generate Coding Prompt').evaluate().length}';
            }
            ..onTimeout = (context) => captureManualScreenshot(
              binding: binding,
              tester: tester,
              name: 'failure_$context',
            );

      final taskCard = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byKey(ValueKey(task.meta.id)),
      );
      final listScrollable = find.descendant(
        of: find.byType(TasksTabPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      );
      final detailScrollable = find.descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
        ),
      );

      await driver.step('intro', () async {
        final tasksRailItem = find
            .text(
              localized(
                en: 'Tasks',
                de: 'Aufgaben',
                fr: 'Tâches',
                it: 'Compiti',
                es: 'Tareas',
                cs: 'Úkoly',
                nl: 'Taken',
                ro: 'Sarcini',
                pt: 'Tarefas',
                da: 'Opgaver',
                sv: 'Uppgifter',
              ),
            )
            .hitTestable();
        await driver.pumpUntilFound(tasksRailItem);
        await driver.holdUntil(const Duration(seconds: 2));
        await driver.tapLikeUser(tasksRailItem);
        await driver.pumpUntilFound(taskCard);
      });

      await driver.step('open_task', () async {
        await driver.scrollIntoView(taskCard, scrollable: listScrollable);
        await driver.tapLikeUser(taskCard.hitTestable());
        await driver.pumpUntilFound(find.byKey(TaskActionBar.audioKey));
      });

      // This scenario starts from a dictated voice note (the "current
      // situation") — its card carries both the transcript and the
      // "Generate…" control.
      final assistantButton = find
          .descendant(
            of: find.byType(TaskDetailsPage),
            matching: find.byTooltip(
              localized(
                en: 'Generate…',
                de: 'Generieren…',
                fr: 'Générer…',
                it: 'Genera...',
                es: 'Generar…',
                cs: 'Generovat…',
                nl: 'Genereren...',
                ro: 'Generează…',
                pt: 'Gerar…',
                da: 'Generer...',
                sv: 'Generera...',
              ),
            ),
          )
          .hitTestable();
      // findRichText: true — flutter_quill's editor renders each line as a
      // bare RichText (text_line.dart), never wrapped in a Text widget, so
      // the default text finder (Text/EditableText only) never matches
      // editor-rendered content at all, regardless of whether it's
      // populated. Scoped to TaskDetailsPage: the demo world's stock task
      // list includes an unrelated seeded task titled "Startprüfung für
      // Project Waddle" in the sidebar, always in the tree — a search for
      // this content unscoped would risk a false match there instead of
      // actually verifying the editor.
      final transcriptText = find.descendant(
        of: find.byType(TaskDetailsPage),
        matching: find.textContaining(
          localized(
            en: 'staging',
            de: 'Staging-Umgebung',
            fr: 'staging',
            it: 'staging',
            es: 'staging',
            cs: 'staging',
            nl: 'staging',
            ro: 'staging',
            pt: 'staging',
            da: 'staging',
            sv: 'staging',
          ),
          findRichText: true,
        ),
      );

      await driver.step('review_transcript', () async {
        // Center the transcript text itself (not the button below it) —
        // Scrollable.ensureVisible walks outward through nested
        // scrollables (the checklist above it has its own reorderable
        // list) from the target's own position, so this reliably frames
        // the transcript regardless of what else is on the page.
        await driver.scrollIntoView(
          transcriptText,
          scrollable: detailScrollable,
        );
        // A dedicated step (its own min_duration/narration in the
        // scenario YAML) so the hold survives the compositor's wait-span
        // compression — a hold embedded mid-step got compressed away.
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 2),
        );
      });

      await driver.step('generate', () async {
        await driver.tapLikeUser(assistantButton.first);

        final skillRow = find.byKey(const ValueKey('skill-prompt-gen-001'));
        await driver.pumpUntilFound(skillRow);
        await driver.tapLikeUser(skillRow.hitTestable());

        // Reasoning-capable skills open a model-override picker (thinking
        // slot) before running — select the profile's configured default
        // (Qwen3.5 122B A10B) rather than overriding it.
        final defaultModelOption = find.text('Qwen3.5 122B A10B').hitTestable();
        await driver.pumpUntilFound(defaultModelOption);
        await driver.tapLikeUser(defaultModelOption.first);
      });

      // The mocked LLM response lands after a short, realistic delay (see
      // _FakeCloudInferenceRepository) — deterministic, so no long timeout
      // is needed here.
      final promptCardTitle = find.text('Generate Coding Prompt');
      await driver.step('prompt_ready', () async {
        await driver.pumpUntilFound(
          promptCardTitle,
          timeout: const Duration(seconds: 30),
        );
        await driver.scrollIntoView(
          promptCardTitle,
          scrollable: detailScrollable,
        );
        // Regression guard: a persistence failure (e.g. a missing getIt
        // registration hit by createDbEntity's post-save side effects)
        // surfaces as this error toast while the card still renders with a
        // placeholder body — catch it here instead of shipping a video with
        // a visible error banner.
        expect(
          find.textContaining('Failed to persist').evaluate(),
          isEmpty,
          reason: 'prompt generation must persist without error',
        );
        // The summary (always visible, even collapsed) must show the real
        // mocked content, not a fallback/placeholder string.
        await driver.pumpUntilFound(
          find.textContaining(
            localized(
              en: 'event-driven pipeline with batched sensor reads',
              de: 'ereignisgesteuerten Pipeline mit gebündelten Sensor-Reads',
              fr: '''pipeline événementiel avec regroupement des lectures de capteurs''',
              it: '''pipeline basata su eventi con letture dei sensori raggruppate''',
              es: '''pipeline basado en eventos con lecturas de sensores agrupadas''',
              cs: '''pipeline řízenou událostmi se seskupenými čteními senzorů''',
              nl: '''gebeurtenisgestuurde pipeline met gebundelde sensormetingen''',
              ro: '''pipeline bazat pe evenimente cu citiri ale senzorilor grupate''',
              pt: '''pipeline orientado a eventos com leituras de sensores agrupadas''',
              da: '''begivenhedsdrevet pipeline med samlede sensoraflæsninger''',
              sv: '''händelsestyrd pipeline med batchade sensoravläsningar''',
            ),
          ),
        );
      });

      await driver.step('scroll_prompt', () async {
        final expandCaret = find.byTooltip(
          localized(
            en: 'Show full prompt',
            de: 'Vollständigen Prompt anzeigen',
            fr: 'Afficher le prompt complet',
            it: 'Mostra il prompt completo',
            es: 'Mostrar prompt completo',
            cs: 'Zobrazit celý prompt',
            nl: 'Volledige prompt tonen',
            ro: 'Afișați promptul complet',
            pt: 'Mostrar prompt completo',
            da: 'Vis fuld prompt',
            sv: 'Visa fullständig prompt',
          ),
        );
        await driver.pumpUntilFound(expandCaret);
        await driver.tapLikeUser(expandCaret.hitTestable());

        final copyButton = find.text(
          localized(
            en: 'Copy Prompt',
            de: 'Prompt kopieren',
            fr: 'Copier le prompt',
            it: 'Copia Prompt',
            es: 'Copiar prompt',
            cs: 'Zkopírovat prompt',
            nl: 'Prompt kopiëren',
            ro: 'Copiați promptul',
            pt: 'Copiar prompt',
            da: 'Kopier prompt',
            sv: 'Kopiera prompt',
          ),
        );
        await driver.pumpUntilFound(copyButton);

        // Scroll through the expanded prompt SLOWLY: small position steps
        // with generous frame time, so viewers can actually read it.
        final scrollableElements = detailScrollable.evaluate().toList();
        ScrollableState? best;
        for (final element in scrollableElements) {
          final state = (element as StatefulElement).state as ScrollableState;
          if (!state.position.hasViewportDimension) continue;
          if (best == null ||
              state.position.viewportDimension >
                  best.position.viewportDimension) {
            best = state;
          }
        }
        expect(best, isNotNull, reason: 'detail pane must be scrollable');
        final position = best!.position;
        while (position.pixels < position.maxScrollExtent - 1) {
          position.jumpTo(
            (position.pixels + 30).clamp(0, position.maxScrollExtent),
          );
          for (var frame = 0; frame < 10; frame++) {
            await driver.tick();
          }
        }
        await driver.holdUntil(
          driver.timeline.elapsed + const Duration(seconds: 1),
        );
      });

      await driver.step('copy_prompt', () async {
        // The copy button is pinned near the card's top (beside its title),
        // not the bottom — scroll_prompt just swept all the way down to
        // read the body, so scroll back up to reach it.
        final copyButton = find
            .text(
              localized(
                en: 'Copy Prompt',
                de: 'Prompt kopieren',
                fr: 'Copier le prompt',
                it: 'Copia Prompt',
                es: 'Copiar prompt',
                cs: 'Zkopírovat prompt',
                nl: 'Prompt kopiëren',
                ro: 'Copiați promptul',
                pt: 'Copiar prompt',
                da: 'Kopier prompt',
                sv: 'Kopiera prompt',
              ),
            )
            .hitTestable();
        await driver.scrollIntoView(copyButton, scrollable: detailScrollable);
        await driver.tapLikeUser(copyButton.first);
        await driver.pumpUntilFound(
          find.text(
            localized(
              en: 'Prompt copied to clipboard',
              de: 'Prompt in Zwischenablage kopiert',
              fr: 'Prompt copié dans le presse-papiers',
              it: 'Prompt copiato a clipboard',
              es: 'Prompt copiado al portapapeles',
              cs: 'Prompt zkopírován do schránky',
              nl: 'Naar klembord gekopieerd',
              ro: 'Prompt copiat în clipboard',
              pt: 'Prompt copiado para a área de transferência',
              da: 'Prompt kopieret til clipboard',
              sv: 'Prompt kopierad till skrivplatta',
            ),
          ),
          timeout: const Duration(seconds: 15),
        );
      });

      await driver.step('outro', () async {});

      driver.timeline.write();
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

/// Skill seed: Melious provider (fake credentials — the actual HTTP call is
/// fully intercepted by `_FakeCloudInferenceRepository`, so no real network
/// access or API key is ever needed) + Qwen thinking model + default
/// profile. The "Generate Coding Prompt" skill runs on the profile's
/// thinking slot.
List<AiConfig> _promptConfigs() {
  final createdAt = DateTime.now();
  return [
    AiConfig.inferenceProvider(
      id: _providerId,
      name: 'Melious.ai',
      baseUrl: 'https://melious.invalid',
      apiKey: 'tutorial-fake-key',
      createdAt: createdAt,
      inferenceProviderType: InferenceProviderType.melious,
    ),
    AiConfig.model(
      id: _thinkingModelId,
      name: 'Qwen3.5 122B A10B',
      providerModelId: 'qwen3.5-122b-a10b',
      inferenceProviderId: _providerId,
      createdAt: createdAt,
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      supportsFunctionCalling: true,
    ),
    AiConfig.inferenceProfile(
      id: _profileId,
      name: 'Tutorial Prompts',
      thinkingModelId: _thinkingModelId,
      createdAt: createdAt,
    ),
  ];
}
