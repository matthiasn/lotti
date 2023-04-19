import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/themes/theme.dart';

// adapted from https://github.com/JohannesMilke/filter_listview_example
class SearchWidget extends StatefulWidget with PreferredSizeWidget {
  const SearchWidget({
    required this.text,
    required this.onChanged,
    this.hintText,
    super.key,
    this.margin = const EdgeInsets.all(20),
  });

  final String text;
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
    final localizations = AppLocalizations.of(context)!;

    final styleActive = searchFieldStyle();
    final styleHint = searchFieldHintStyle();

    final style = widget.text.isEmpty ? styleHint : styleActive;

    return Container(
      margin: widget.margin,
      height: 53,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: styleConfig().cardColor,
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: style.color),
          suffixIcon: Visibility(
            visible: controller.text.isNotEmpty,
            child: GestureDetector(
              child: Icon(
                Icons.close_rounded,
                color: style.color,
              ),
              onTap: () {
                controller.clear();
                widget.onChanged('');
                FocusScope.of(context).requestFocus(FocusNode());
              },
            ),
          ),
          hintText: widget.hintText ?? localizations.searchHint,
          hintStyle: style,
          border: InputBorder.none,
        ),
        style: style,
        onChanged: widget.onChanged,
      ),
    );
  }
}
