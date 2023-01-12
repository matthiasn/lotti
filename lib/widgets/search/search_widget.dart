import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

// adapted from https://github.com/JohannesMilke/filter_listview_example
class SearchWidget extends StatefulWidget with PreferredSizeWidget {
  const SearchWidget({
    super.key,
    required this.text,
    required this.onChanged,
    required this.hintText,
    this.margin = const EdgeInsets.all(20),
  });

  final String text;
  final ValueChanged<String> onChanged;
  final String hintText;
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
    final styleActive = searchFieldStyle();
    final styleHint = searchFieldHintStyle();

    final style = widget.text.isEmpty ? styleHint : styleActive;

    return Container(
      margin: widget.margin,
      height: 53,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.black26),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: style.color),
          suffixIcon: GestureDetector(
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
          hintText: widget.hintText,
          hintStyle: style,
          border: InputBorder.none,
        ),
        style: style,
        onChanged: widget.onChanged,
      ),
    );
  }
}
