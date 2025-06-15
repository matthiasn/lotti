import 'package:flutter/material.dart';
import 'package:lotti/features/speech/ui/pages/polished_record_audio_page.dart';
import 'package:lotti/features/speech/ui/pages/record_audio_page.dart';

class SwitchableRecordAudioPage extends StatefulWidget {
  const SwitchableRecordAudioPage({
    super.key,
    this.linkedId,
    this.categoryId,
  });

  final String? linkedId;
  final String? categoryId;

  @override
  State<SwitchableRecordAudioPage> createState() => _SwitchableRecordAudioPageState();
}

class _SwitchableRecordAudioPageState extends State<SwitchableRecordAudioPage> {
  bool _usePolishedDesign = true;

  @override
  Widget build(BuildContext context) {
    if (_usePolishedDesign) {
      return Stack(
        children: [
          PolishedRecordAudioPage(
            linkedId: widget.linkedId,
            categoryId: widget.categoryId,
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.grey.withOpacity(0.8),
              onPressed: () {
                setState(() {
                  _usePolishedDesign = !_usePolishedDesign;
                });
              },
              child: const Icon(Icons.swap_horiz, size: 20),
            ),
          ),
        ],
      );
    } else {
      return Stack(
        children: [
          RecordAudioPage(
            linkedId: widget.linkedId,
            categoryId: widget.categoryId,
          ),
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.grey.withOpacity(0.8),
              onPressed: () {
                setState(() {
                  _usePolishedDesign = !_usePolishedDesign;
                });
              },
              child: const Icon(Icons.swap_horiz, size: 20),
            ),
          ),
        ],
      );
    }
  }
}