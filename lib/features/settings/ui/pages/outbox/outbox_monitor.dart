import 'package:drift/drift.dart' as drift;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class OutboxMonitorPage extends StatefulWidget {
  const OutboxMonitorPage({
    super.key,
  });

  @override
  State<OutboxMonitorPage> createState() => _OutboxMonitorPageState();
}

class _OutboxMonitorPageState extends State<OutboxMonitorPage> {
  final SyncDatabase _db = getIt<SyncDatabase>();
  late Stream<List<OutboxItem>> stream =
      _db.watchOutboxItems(statuses: [OutboxStatus.pending]);
  String _selectedValue = 'pending';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OutboxCubit, OutboxState>(
      builder: (_, OutboxState state) {
        return StreamBuilder<List<OutboxItem>>(
          stream: stream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<OutboxItem>> snapshot,
          ) {
            final items = snapshot.data ?? [];
            final onlineStatus = state is! OutboxDisabled;

            void onValueChanged(String value) {
              setState(() {
                _selectedValue = value;
                if (_selectedValue == 'all') {
                  stream = _db.watchOutboxItems();
                }
                if (_selectedValue == 'pending') {
                  stream = _db.watchOutboxItems(
                    statuses: [OutboxStatus.pending],
                  );
                }
                if (_selectedValue == 'error') {
                  stream = _db.watchOutboxItems(
                    statuses: [OutboxStatus.error],
                  );
                }
              });
            }

            return Scaffold(
              appBar: OutboxAppBar(
                onlineStatus: onlineStatus,
                selectedValue: _selectedValue,
                onValueChanged: onValueChanged,
              ),
              body: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(8),
                children: List.generate(
                  items.length,
                  (int index) {
                    return OutboxItemCard(
                      item: items.elementAt(index),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OutboxItemCard extends StatelessWidget {
  OutboxItemCard({
    required this.item,
    super.key,
  });

  final SyncDatabase _db = getIt<SyncDatabase>();
  final OutboxItem item;

  @override
  Widget build(BuildContext context) {
    final statusEnum = OutboxStatus.values[item.status];

    String getStringFromStatus(OutboxStatus x) {
      switch (x) {
        case OutboxStatus.pending:
          return context.messages.outboxMonitorLabelPending;
        case OutboxStatus.sent:
          return context.messages.outboxMonitorLabelSent;
        case OutboxStatus.error:
          return context.messages.outboxMonitorLabelError;
      }
    }

    final status = getStringFromStatus(statusEnum);

    Color cardColor(OutboxStatus status) {
      switch (statusEnum) {
        case OutboxStatus.pending:
          return Theme.of(context).primaryColorLight;
        case OutboxStatus.error:
          return context.colorScheme.error;
        case OutboxStatus.sent:
          return Theme.of(context).primaryColor;
      }
    }

    final retriesText = item.retries == 1
        ? context.messages.outboxMonitorRetry
        : context.messages.outboxMonitorRetries;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Card(
        color: cardColor(statusEnum).withAlpha(102),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 24, right: 24),
          title: Text(
            '${df.format(item.createdAt)} - $status',
            style: const TextStyle(fontSize: fontSizeMedium),
          ),
          subtitle: Text(
            '${item.retries} $retriesText \n'
            '${item.filePath ?? context.messages.outboxMonitorNoAttachment}',
            style: const TextStyle(
              fontWeight: FontWeight.w200,
              fontSize: fontSizeSmall,
            ),
          ),
          onTap: () {
            if (statusEnum == OutboxStatus.error) {
              _db.updateOutboxItem(
                OutboxCompanion(
                  id: drift.Value(item.id),
                  status: drift.Value(OutboxStatus.pending.index),
                  retries: drift.Value(item.retries + 1),
                  updatedAt: drift.Value(DateTime.now()),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

const toolbarHeight = 88.0;

class OutboxAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OutboxAppBar({
    required this.onlineStatus,
    required this.selectedValue,
    required this.onValueChanged,
    super.key,
  });

  final bool onlineStatus;
  final String selectedValue;
  final void Function(String value) onValueChanged;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.messages.settingsSyncOutboxTitle,
                style: appBarTextStyle,
              ),
              const SizedBox(width: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.messages.outboxMonitorSwitchLabel),
                  CupertinoSwitch(
                    value: onlineStatus,
                    onChanged: (_) {
                      context.read<OutboxCubit>().toggleStatus();
                    },
                  ),
                ],
              ),
            ],
          ),
          CupertinoSegmentedControl(
            groupValue: selectedValue,
            onValueChanged: onValueChanged,
            children: {
              'pending': SizedBox(
                width: 64,
                height: 32,
                child: Center(
                  child: Text(
                    context.messages.outboxMonitorLabelPending,
                    style: segmentItemStyle,
                  ),
                ),
              ),
              'error': SizedBox(
                child: Center(
                  child: Text(
                    context.messages.outboxMonitorLabelError,
                    style: segmentItemStyle,
                  ),
                ),
              ),
              'all': SizedBox(
                child: Center(
                  child: Text(
                    context.messages.outboxMonitorLabelAll,
                    style: segmentItemStyle,
                  ),
                ),
              ),
            },
          ),
        ],
      ),
      toolbarHeight: toolbarHeight,
      centerTitle: true,
    );
  }
}
