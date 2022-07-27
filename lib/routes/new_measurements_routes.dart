import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/new_measurements_page.dart';

const AutoRoute newMeasurementsRoutes = AutoRoute(
  path: 'newmeasurements',
  name: 'NewMeasurementsRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: NewMeasurementsPage,
    )
  ],
);

