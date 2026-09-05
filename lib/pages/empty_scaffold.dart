import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_ui/material_ui.dart';

class EmptyScaffoldWithTitle extends StatelessWidget {
  const EmptyScaffoldWithTitle(
    this.title, {
    super.key,
    this.body,
  });

  final String title;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(title: title),
      body: body,
    );
  }
}
