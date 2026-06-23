import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/services/sync_node_profile_broadcaster.dart';
import 'package:lotti/features/sync/state/synced_audio_inference_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Settings page for the local sync-node profile and the directory of known
/// peer profiles.
///
/// Lets the user rename this device (the name appears in other devices'
/// pinning UI), surface the auto-detected capabilities, and review which
/// peers have advertised their own profiles.
///
/// All save actions go through `SyncNodeProfileBroadcaster.broadcastIfChanged`
/// — that path re-broadcasts on a real name change but suppresses a no-op
/// re-save, matching how `inference_profile_form.dart` preserves the pin on
/// unrelated edits.
class SyncNodeProfilePage extends ConsumerStatefulWidget {
  const SyncNodeProfilePage({super.key});

  @override
  ConsumerState<SyncNodeProfilePage> createState() =>
      _SyncNodeProfilePageState();
}

class _SyncNodeProfilePageState extends ConsumerState<SyncNodeProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  String? _lastSeededFromHostId;
  String _seededName = '';

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the Save button can reflect whether
    // the trimmed text differs from the seeded self name.
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleNameChanged)
      ..dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) setState(() {});
  }

  void _seedName(SyncNodeProfile? self) {
    // Seed only when we first see the self profile for a given host id —
    // after that, the user owns the text field.
    if (self == null) return;
    if (_lastSeededFromHostId == self.hostId) return;
    _lastSeededFromHostId = self.hostId;
    _seededName = self.displayName;
    _nameController.text = self.displayName;
  }

  bool get _hasUnsavedChanges {
    // No self profile loaded yet → nothing to compare against, no save.
    if (_lastSeededFromHostId == null) return false;
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) return false;
    return trimmed != _seededName.trim();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final broadcaster = getIt<SyncNodeProfileBroadcaster>();
      final newName = _nameController.text.trim();
      await broadcaster.broadcastIfChanged(displayNameOverride: newName);
      _seededName = newName;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final selfAsync = ref.watch(localSyncNodeSelfProvider);
    final directoryAsync = ref.watch(knownSyncNodesProvider);

    final self = selfAsync.maybeWhen<SyncNodeProfile?>(
      data: (value) => value,
      orElse: () => null,
    );
    // Seed after this build commits so setting the controller text — which
    // notifies the listener that calls setState — doesn't trigger a
    // setState-during-build assertion. A no-op on subsequent builds (the
    // `_lastSeededFromHostId` guard inside `_seedName` short-circuits).
    if (self != null && _lastSeededFromHostId != self.hostId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seedName(self);
      });
    }

    final knownNodes = directoryAsync.maybeWhen<List<SyncNodeProfile>>(
      data: (value) =>
          value.where((n) => self == null || n.hostId != self.hostId).toList(),
      orElse: () => const <SyncNodeProfile>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(messages.settingsSyncNodeProfileTitle),
        actions: [
          Tooltip(
            message: _hasUnsavedChanges
                ? messages.settingsSyncNodeProfileSaveButton
                : messages.aiFormNoChanges,
            child: DesignSystemButton(
              label: messages.settingsSyncNodeProfileSaveButton,
              leadingIcon: Icons.save_rounded,
              onPressed: (_isSaving || !_hasUnsavedChanges) ? null : _save,
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              messages.settingsSyncNodeProfileSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: messages.settingsSyncNodeProfileDisplayNameLabel,
                helperText: messages.settingsSyncNodeProfileDisplayNameHelper,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return messages.settingsSyncNodeProfileDisplayNameLabel;
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              messages.settingsSyncNodeProfileCapabilitiesLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _CapabilityChips(self: self),
            const SizedBox(height: 24),
            Text(
              messages.settingsSyncNodeProfileKnownNodesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (knownNodes.isEmpty)
              Text(
                messages.settingsSyncNodeProfileKnownNodesEmpty,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...knownNodes.map(_KnownNodeTile.new),
          ],
        ),
      ),
    );
  }
}

String _capabilityLabel(BuildContext context, NodeCapability cap) {
  final m = context.messages;
  return switch (cap) {
    NodeCapability.mlxAudio => m.settingsSyncNodeProfileCapabilityMlxAudio,
    NodeCapability.omlxLlm => m.settingsSyncNodeProfileCapabilityOmlxLlm,
    NodeCapability.ollamaLlm => m.settingsSyncNodeProfileCapabilityOllamaLlm,
    NodeCapability.voxtral => m.settingsSyncNodeProfileCapabilityVoxtral,
    NodeCapability.whisper => m.settingsSyncNodeProfileCapabilityWhisper,
  };
}

class _CapabilityChips extends StatelessWidget {
  const _CapabilityChips({required this.self});

  final SyncNodeProfile? self;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final caps = self?.capabilities ?? const <NodeCapability>[];
    if (caps.isEmpty) {
      return Text(
        messages.settingsSyncNodeProfileCapabilitiesEmpty,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cap in caps)
          DesignSystemBadge.outlined(
            label: _capabilityLabel(context, cap),
            tone: DesignSystemBadgeTone.secondary,
          ),
      ],
    );
  }
}

class _KnownNodeTile extends StatelessWidget {
  const _KnownNodeTile(this.node);

  final SyncNodeProfile node;

  @override
  Widget build(BuildContext context) {
    final caps = node.capabilities
        .map((c) => _capabilityLabel(context, c))
        .toList(growable: false)
        .join(', ');
    return ListTile(
      title: Text(node.displayName),
      subtitle: Text(
        '${node.platform}'
        '${caps.isEmpty ? '' : ' · $caps'}',
      ),
    );
  }
}
