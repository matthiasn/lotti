import 'package:flutter/material.dart';

class TasksManual extends StatelessWidget {
  const TasksManual({required this.tasksManualList, super.key});

  final List<String> tasksManualList;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: tasksManualList.length,
      itemBuilder: (context, index) {
        if (index.isEven) {
          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: 110,
                  child: Image.asset(
                    'assets/images/manual/src_icon.png',
                  ),
                ),
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Navigate through your tasks effortlessly with the search function.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(
                  width: 120,
                  child: Text(
                    'Navigate through your tasks effortlessly with the search function.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  width: 110,
                  child: Image.asset(
                    'assets/images/manual/src_icon.png',
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
