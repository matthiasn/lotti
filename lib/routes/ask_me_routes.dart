import 'package:auto_route/auto_route.dart';
import 'package:lotti/pages/ask_me_page.dart';

const AutoRoute askMeRoutes = AutoRoute(
  path: 'askme',
  name: 'AskMeRouter',
  page: EmptyRouterPage,
  children: [
    AutoRoute(
      path: '',
      page: AskMePage,
    )
  ],
);

