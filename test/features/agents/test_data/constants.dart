import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';

/// Default template ID used across tests.
const kTestTemplateId = 'template-001';

/// Shared test date for agent tests. Do NOT use DateTime.now().
final kAgentTestDate = DateTime(2024, 3, 15, 10, 30);

/// Default agent ID used across tests.
const kTestAgentId = 'agent-001';

/// Default task metadata snapshot for redundancy-filter tests.
const kTestTaskMetadataSnapshot =
    (
          title: 'Fix login bug',
          status: 'IN PROGRESS',
          priority: 'P1',
          estimateMinutes: 120,
          dueDate: '2026-03-15',
          languageCode: 'en',
        )
        as TaskMetadataSnapshot;
