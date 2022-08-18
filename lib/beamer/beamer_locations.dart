import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/pages/dashboards/dashboard_page.dart';
import 'package:lotti/pages/dashboards/dashboards_list_page.dart';
import 'package:lotti/pages/journal/journal_page.dart';
import 'package:lotti/pages/settings/flags_page.dart';
import 'package:lotti/pages/settings/settings_page.dart';
import 'package:lotti/pages/tasks/tasks_page.dart';

// DATA
const List<Map<String, String>> books = [
  {
    'id': '1',
    'title': 'Stranger in a Strange Land',
    'author': 'Robert A. Heinlein',
  },
  {
    'id': '2',
    'title': 'Foundation',
    'author': 'Isaac Asimov',
  },
  {
    'id': '3',
    'title': 'Fahrenheit 451',
    'author': 'Ray Bradbury',
  },
];

const List<Map<String, String>> articles = [
  {
    'id': '1',
    'title': 'Explaining Flutter Nav 2.0 and Beamer',
    'author': 'Toby Lewis',
  },
  {
    'id': '2',
    'title': 'Flutter Navigator 2.0 for mobile dev: 101',
    'author': 'Lulupointu',
  },
  {
    'id': '3',
    'title': 'Flutter: An Easy and Pragmatic Approach to Navigator 2.0',
    'author': 'Marco Muccinelli',
  },
];

// SCREENS
class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Books'),
      ),
      body: ListView(
        children: books
            .map(
              (book) => ListTile(
                title: Text(book['title']!),
                subtitle: Text(book['author']!),
                onTap: () => context.beamToNamed('/books/${book['id']}'),
              ),
            )
            .toList(),
      ),
    );
  }
}

class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({required this.book, super.key});
  final Map<String, String> book;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(book['title']!),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Author: ${book['author']}'),
      ),
    );
  }
}

// LOCATIONS
class BooksLocation extends BeamLocation<BeamState> {
  BooksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/books/:bookId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('books'),
          title: 'Books',
          type: BeamPageType.noTransition,
          child: BooksScreen(),
        ),
        if (state.pathParameters.containsKey('bookId'))
          BeamPage(
            key: ValueKey('book-${state.pathParameters['bookId']}'),
            title: books.firstWhere(
              (book) => book['id'] == state.pathParameters['bookId'],
            )['title'],
            child: BookDetailsScreen(
              book: books.firstWhere(
                (book) => book['id'] == state.pathParameters['bookId'],
              ),
            ),
          ),
      ];
}

class DashboardsLocation extends BeamLocation<BeamState> {
  DashboardsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/dashboards/dashboard/:dashboardId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('dashboards'),
          title: 'Dashboards',
          type: BeamPageType.noTransition,
          child: DashboardsListPage(),
        ),
        if (state.pathParameters.containsKey('dashboardId'))
          BeamPage(
            key: ValueKey('dashboards-${state.pathParameters['dashboardId']}'),
            child: DashboardPage(
              dashboardId: state.pathParameters['dashboardId']!,
              showBackIcon: false,
            ),
          ),
      ];
}

class JournalLocation extends BeamLocation<BeamState> {
  JournalLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/journal/:entryId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('journal'),
          title: 'Journal',
          type: BeamPageType.noTransition,
          child: JournalPage(),
        ),
        if (state.pathParameters.containsKey('entryId'))
          BeamPage(
            key: ValueKey('articles-${state.pathParameters['articleId']}'),
            title: articles.firstWhere(
              (article) => article['id'] == state.pathParameters['articleId'],
            )['title'],
            child: BookDetailsScreen(
              book: articles.firstWhere(
                (article) => article['id'] == state.pathParameters['articleId'],
              ),
            ),
          ),
      ];
}

class TasksLocation extends BeamLocation<BeamState> {
  TasksLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/tasks/:taskId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('tasks'),
          title: 'Tasks',
          type: BeamPageType.noTransition,
          child: TasksPage(),
        ),
        if (state.pathParameters.containsKey('articleId'))
          BeamPage(
            key: ValueKey('articles-${state.pathParameters['articleId']}'),
            title: articles.firstWhere(
              (article) => article['id'] == state.pathParameters['articleId'],
            )['title'],
            child: BookDetailsScreen(
              book: articles.firstWhere(
                (article) => article['id'] == state.pathParameters['articleId'],
              ),
            ),
          ),
      ];
}

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/settings/:taskId'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('settings'),
          title: 'Settings',
          type: BeamPageType.noTransition,
          child: SettingsPage(),
        ),
        if (state.pathParameters.containsKey('articleId'))
          BeamPage(
            key: ValueKey('articles-${state.pathParameters['articleId']}'),
            title: articles.firstWhere(
              (article) => article['id'] == state.pathParameters['articleId'],
            )['title'],
            child: BookDetailsScreen(
              book: articles.firstWhere(
                (article) => article['id'] == state.pathParameters['articleId'],
              ),
            ),
          ),
      ];
}

class ConfigFlagsLocation extends BeamLocation<BeamState> {
  ConfigFlagsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/config_flags/'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        const BeamPage(
          key: ValueKey('settings'),
          title: 'Settings',
          type: BeamPageType.noTransition,
          child: FlagsPage(),
        ),
      ];
}
