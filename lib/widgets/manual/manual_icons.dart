import 'package:flutter/material.dart';

class ManualIcons extends StatelessWidget {
  const ManualIcons({
    required this.mainAxisAlignment,
    required this.icon1,
    required this.icon2,
    required this.iconFunc,
    required this.iconFunc2,
    super.key,
  });

  final MainAxisAlignment mainAxisAlignment;
  final IconData icon1;
  final IconData icon2;
  final Widget iconFunc;
  final Widget iconFunc2;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        children: [
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      child: Positioned(
                        top: MediaQuery.of(context).size.height *
                            0.14, // 30% from top
                        left: 20,
                        right: 20,
                        child: AlertDialog(
                          title: iconFunc,
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('x'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            child: Icon(
              icon1,
              size: 35,
            ),
          ),
          GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) {
                return Stack(
                  children: [
                    Positioned(
                      height: 100,
                      top: MediaQuery.of(context).size.height *
                          0.14, // % from top
                      left: 20,
                      right: 20,
                      child: AlertDialog(
                        title: iconFunc2,
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text('x'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            child: Icon(
              icon2,
              size: 35,
            ),
          ),
        ],
      ),
    );
  }
}
