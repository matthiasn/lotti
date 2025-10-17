import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/state/matrix_login_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage homeServerLoggedInPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: LoggedInPageStickyActionBar(
      pageIndexNotifier: pageIndexNotifier,
    ),
    title: context.messages.settingsMatrixHomeserverConfigTitle,
    child: const HomeserverLoggedInWidget(),
  );
}

class LoggedInPageStickyActionBar extends ConsumerWidget {
  const LoggedInPageStickyActionBar({
    required this.pageIndexNotifier,
    super.key,
  });

  final ValueNotifier<int> pageIndexNotifier;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: LottiSecondaryButton(
              label: context.messages.settingsMatrixLogoutButtonLabel,
              onPressed: () async {
                await ref.read(matrixLoginControllerProvider.notifier).logout();
                pageIndexNotifier.value = 0;
              },
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: LottiPrimaryButton(
              onPressed: () => pageIndexNotifier.value = 2,
              label: context.messages.settingsMatrixNextPage,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeserverLoggedInWidget extends ConsumerStatefulWidget {
  const HomeserverLoggedInWidget({super.key});

  @override
  ConsumerState<HomeserverLoggedInWidget> createState() =>
      _HomeserverLoggedInWidgetState();
}

class _HomeserverLoggedInWidgetState
    extends ConsumerState<HomeserverLoggedInWidget> {
  StreamSubscription<SyncRoomInvite>? _inviteSub;
  bool _dialogOpen = false;

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Listen for invites while this page (QR view) is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matrixService = ref.read(matrixServiceProvider);
      _inviteSub =
          matrixService.inviteRequests.listen((SyncRoomInvite invite) async {
        if (!mounted || _dialogOpen) return;
        _dialogOpen = true;
        try {
          final accept = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Room invite'),
                  content: Text(
                      'Invite to room ${invite.roomId} from ${invite.senderId}. Accept?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (accept) {
            await ref.read(matrixServiceProvider).acceptInvite(invite);
            if (mounted) setState(() {});
          }
        } catch (_) {
          // ignore dialog errors
        } finally {
          _dialogOpen = false;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final userIdAsyncValue = ref.watch(loggedInUserIdProvider);

    return userIdAsyncValue.map(
      data: (data) {
        final userId = data.valueOrNull;

        if (userId == null) {
          return const CircularProgressIndicator();
        }

        return Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(
                    data: userId,
                    padding: EdgeInsets.zero,
                    size: 240,
                    key: const Key('QrImage'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(userId, style: context.textTheme.bodyLarge),
            const SizedBox(height: 10),
            Text(
              context.messages.settingsMatrixQrTextPage,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            const DiagnosticInfoButton(),
            const SizedBox(height: 80),
          ],
        );
      },
      error: (error) {
        return Text(error.valueOrNull.toString());
      },
      loading: (loading) {
        return const CircularProgressIndicator();
      },
    );
  }
}

class DiagnosticInfoButton extends ConsumerWidget {
  const DiagnosticInfoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LottiSecondaryButton(
      label: 'Show Diagnostic Info',
      onPressed: () async {
        final info = await ref.read(matrixServiceProvider).getDiagnosticInfo();
        final prettyJson = const JsonEncoder.withIndent('  ').convert(info);

        if (!context.mounted) return;

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sync Diagnostic Info'),
            content: SingleChildScrollView(
              child: SelectableText(
                prettyJson,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prettyJson));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Diagnostic info copied to clipboard'),
                      ),
                    );
                  }
                },
                child: const Text('Copy to Clipboard'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}
