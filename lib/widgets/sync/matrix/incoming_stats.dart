import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/get_it.dart';

class IncomingStats extends StatelessWidget {
  const IncomingStats({super.key});

  @override
  Widget build(BuildContext context) {
    final matrixService = getIt<MatrixService>();

    return StreamBuilder(
      stream: matrixService.messageCountsController.stream,
      builder: (context, snapshot) {
        final data = snapshot.data ??
            MatrixStats(
              sentCount: matrixService.sentCount,
              messageCounts: matrixService.messageCounts,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent messages: ${data.sentCount}'),
            const SizedBox(height: 10),
            DataTable(
              columns: const <DataColumn>[
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Message Type',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
                DataColumn(
                  label: Expanded(
                    child: Text(
                      'Count',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              ],
              rows: <DataRow>[
                ...data.messageCounts.keys.map(
                  (k) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(k)),
                      DataCell(Text(data.messageCounts[k].toString())),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
