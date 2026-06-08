import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/ui/instances/instance_view_model.dart';

InstanceVm hVm({
  required String id,
  required String name,
  required InstanceType type,
  required AgentLifecycle status,
  required DateTime updatedAt,
  String? soulName,
  String? soulId,
  String? templateName,
  String? templateId,
  int? sessionNumber,
}) {
  return InstanceVm(
    id: id,
    displayName: name,
    type: type,
    status: status,
    updatedAt: updatedAt,
    sessionNumber: sessionNumber,
    soulName: soulName,
    soulId: soulId,
    templateId: templateId,
    templateName: templateName,
    searchKey: '$name $id ${soulName ?? ''} ${templateName ?? ''}'
        .toLowerCase(),
  );
}
