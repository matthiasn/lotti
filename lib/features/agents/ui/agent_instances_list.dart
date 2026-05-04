import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/instances/agent_instances_page.dart';

/// Public entry point used by `AgentSettingsPage` for the
/// `Settings → Agents → Instances` tab.
///
/// The actual UI lives in [AgentInstancesPage] under
/// `lib/features/agents/ui/instances/`. This shell stays for the
/// existing import path (`agent_instances_list.dart`).
class AgentInstancesList extends StatelessWidget {
  const AgentInstancesList({super.key});

  @override
  Widget build(BuildContext context) => const AgentInstancesPage();
}
