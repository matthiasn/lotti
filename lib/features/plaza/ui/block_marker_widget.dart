import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// The week label painted on the road at the start of a block, readable
/// from the overview pose. Captured once at build.
class BlockMarkerWidget extends StatelessWidget {
  const BlockMarkerWidget({
    required this.label,
    required this.heightMeters,
    required this.pxPerMeter,
    super.key,
  });

  final String label;
  final double heightMeters;
  final double pxPerMeter;

  @override
  Widget build(BuildContext context) {
    final fontPx = heightMeters * pxPerMeter * 0.4;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(fontPx * 0.25),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: PlazaStyle.fontMono,
            fontSize: fontPx,
            fontWeight: FontWeight.w500,
            color: const Color(0xD9FFFFFF),
          ),
        ),
      ),
    );
  }
}
