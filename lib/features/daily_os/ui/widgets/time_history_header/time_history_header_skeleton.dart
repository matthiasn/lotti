// Loading-state chrome for the time-history header: the day-selector
// skeleton, the load-more spinner, and the horizontal-only clipper.
// Part of the time_history_header_widget library so the helpers keep
// access to the State's context and layout constants.
part of 'time_history_header_widget.dart';

extension _TimeHistoryHeaderSkeleton on _TimeHistoryHeaderState {
  Widget _buildDaySelectorSkeleton() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      reverse: true,
      itemCount: 7,
      itemExtent: daySegmentWidth,
      itemBuilder: (context, index) {
        return Container(
          width: daySegmentWidth,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 12,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 16,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: daySegmentWidth,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Horizontal-only clipper that clips at tomorrow noon on the right.
/// Allows unlimited vertical overflow (no top/bottom clipping).
class _HorizontalClipper extends CustomClipper<Rect> {
  _HorizontalClipper({required this.clipRightX});

  final double clipRightX;

  @override
  Rect getClip(Size size) {
    // Use large vertical extent to allow overflow; only clip horizontally
    const verticalExtent = 10000.0;
    final rightEdge = clipRightX.isFinite ? clipRightX : double.infinity;
    return Rect.fromLTRB(
      -verticalExtent,
      -verticalExtent,
      rightEdge,
      verticalExtent,
    );
  }

  @override
  bool shouldReclip(_HorizontalClipper oldClipper) {
    return oldClipper.clipRightX != clipRightX;
  }
}
