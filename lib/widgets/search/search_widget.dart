import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

// adapted from https://github.com/JohannesMilke/filter_listview_example
class SearchWidget extends StatefulWidget implements PreferredSizeWidget {
  const SearchWidget({
    required this.onChanged,
    this.hintText,
    super.key,
    this.margin = const EdgeInsets.all(20),
  });

  final ValueChanged<String> onChanged;
  final String? hintText;
  final EdgeInsets margin;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context)
          .copyWith(inputDecorationTheme: const InputDecorationTheme()),
      child: Container(
        margin: widget.margin,
        height: 53,
        padding: const EdgeInsets.only(left: 10),
        child: SearchBar(
          controller: controller,
          hintText: widget.hintText ?? context.messages.searchHint,
          onChanged: widget.onChanged,
          leading: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.search),
          ),
          trailing: [
            Visibility(
              visible: controller.text.isNotEmpty,
              child: GestureDetector(
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.close_rounded,
                  ),
                ),
                onTap: () {
                  controller.clear();
                  widget.onChanged('');
                  FocusScope.of(context).requestFocus(FocusNode());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
