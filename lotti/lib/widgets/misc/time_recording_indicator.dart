import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class TimeRecordingIndicator extends StatelessWidget {
  const TimeRecordingIndicator({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
        top: (MediaQuery.of(context).size.height / 2) - 40,
        left: 0,
        child: GestureDetector(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                color: AppColors.timeRecording,
                width: 24,
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        '00:25:16',
                        style: TextStyle(
                          fontFamily: 'ShareTechMono',
                          fontSize: 18.0,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
