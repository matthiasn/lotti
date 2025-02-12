import 'package:flutter/material.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ManualIcons extends StatelessWidget {
  const ManualIcons({
    required this.mainAxisAlignment,
    required this.icon1,
    required this.icon2,
    required this.iconFunc,
    required this.iconFunc2,
    this.manualheader = const Row(mainAxisAlignment: MainAxisAlignment.center),
    super.key,
  });

  final MainAxisAlignment mainAxisAlignment;
  final IconData icon1;
  final IconData icon2;
  final Widget iconFunc;
  final Widget iconFunc2;
  final Widget manualheader;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      child: Row(
        mainAxisAlignment: mainAxisAlignment,
        children: [
          GestureDetector(
            onTap: () {
              WoltModalSheet.show<void>(
                context: context,
                modalTypeBuilder: (context) => WoltModalType.dialog(),
                pageListBuilder: (context) {
                  return [
                    WoltModalSheetPage(
                      hasSabGradient: false,
                      stickyActionBar: const Padding(
                        padding: EdgeInsets.all(10),
                      ),
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: Navigator.of(context).pop,
                            child: SizedBox(
                              width: double.infinity,
                              child: iconFunc,
                            ),
                          ),
                        ],
                      ),
                      topBarTitle: manualheader,
                      isTopBarLayerAlwaysVisible: true,
                      trailingNavBarWidget: IconButton(
                        onPressed: Navigator.of(context).pop,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ];
                },
              );
            },
            child: Icon(
              icon1,
              size: 35,
            ),
          ),
          
           GestureDetector(
            onTap: () {
              WoltModalSheet.show<void>(
                context: context,
                modalTypeBuilder: (context) => WoltModalType.dialog(),
                pageListBuilder: (context) {
                  return [
                    WoltModalSheetPage(
                      hasSabGradient: false,
                      stickyActionBar: const Padding(
                        padding: EdgeInsets.all(10),
                      ),
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: Navigator.of(context).pop,
                            child: SizedBox(
                              width: double.infinity,
                              child: iconFunc2,
                            ),
                          ),
                        ],
                      ),
                     
                      isTopBarLayerAlwaysVisible: true,
                      trailingNavBarWidget: IconButton(
                        onPressed: Navigator.of(context).pop,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ];
                },
              );
            },
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
