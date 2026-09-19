import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// The phone route for one check-in (`/people/<id>/check-ins/<checkInId>`):
/// [CheckInDetailView] on its own page, leading back to the person. On
/// desktop the same view fills the People detail pane instead.
class CheckInDetailPage extends StatelessWidget {
  const CheckInDetailPage({
    required this.relationshipId,
    required this.checkInId,
    super.key,
  });

  final String relationshipId;
  final String checkInId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CheckInDetailView(
          relationshipId: relationshipId,
          checkInId: checkInId,
          onBack: () => beamToNamed('/people/$relationshipId'),
        ),
      ),
    );
  }
}
