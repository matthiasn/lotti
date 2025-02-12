import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lotti/pages/settings/sliver_box_adapter_page.dart';
import 'package:lotti/widgets/manual/manual_icons.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ManualPage extends StatelessWidget {
  const ManualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: 'Lotti Manual',
      showBackButton: true,
      child: Expanded(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              child: const Text(
                '''
Lotti is a behavioral monitoring and journaling app that lets you keep track of anything you can measure. 
Measurements could, for example, include tracking exercises, plus imported data from Apple Health or the equivalent on Android. 
In terms of behavior, you can monitor habits, e.g. such that are related to measurables. 
This could be the intake of medication, numbers of repetitions of an exercise, 
the amount of water you drink, the amount of fiber you ingest, you name it. 
Anything you can imagine. If you create a habit, you can assign any dashboard you want, and then by 
the time you want to complete a habit, look at the data and determine at a quick glance of the 
conditions are indeed met for successful completion.
              ''',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            ManualIcons(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              icon1: Icons.check_circle_outlined,
              icon2: Ionicons.book_outline,
              manualheader: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outlined,
                  ),
                  Text(
                    'Tasks',
                  ),
                ],
              ),
              iconFunc: SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      const SizedBox(
                        child: Text(
                          'The task interface helps you maintain control over your task entries while providing flexibility in how you organize and manage your personal information.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
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
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Organize your view by filtering tasks your way.',
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
                              'assets/images/manual/filter_icon.png',
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: 110,
                            child: Image.asset(
                              'assets/images/manual/addTask.png',
                            ),
                          ),
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Your gateway to task creation, revealing these powerful options:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Mark standout tasks that deserve special attention.',
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
                            width: 130,
                            child: Image.asset(
                              'assets/images/manual/starred_icon.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: 110,
                            child: Image.asset(
                              'assets/images/manual/flag_icon.png',
                            ),
                          ),
                          const SizedBox(
                            width: 130,
                            child: Text(
                              'Highlight tasks that need follow-up or special focus.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 80,
                            child: Text(
                              '1. Task Name Field e.g. "Plan weekly grocery shopping".',
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
                            width: 190,
                            child: Image.asset(
                              'assets/images/manual/taskname_icon.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: 150,
                            child: Image.asset(
                              'assets/images/manual/taskTime_stamp.png',
                            ),
                          ),
                          const SizedBox(
                            width: 110,
                            child: Text(
                              '2. Time Estimate. e.g. 01:30 hours. \n\n3. Status Tracker Track progress: \nOpen → Groomed → In Progress → Complete',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 110,
                            child: Text(
                              '4. Category Management. \n- Select existing or create new \n- Pick your color \n- e.g. House Chores\n\n5. Color Picker \n- Choose custom colors \n- Personalize categories \n- Visual organization',
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
                            width: 150,
                            child: Image.asset(
                              'assets/images/manual/setCate_icon.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: 130,
                            child: Image.asset(
                              'assets/images/manual/taskNote_icon.png',
                            ),
                          ),
                          const SizedBox(
                            width: 130,
                            child: Text(
                              '6. Smart Notes. \ne.g:\n - Bring reusable bags \n- Fresh produce section \n- Pantry essentials',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 130,
                            child: Text(
                              '7. Interactive Checklists. \ne.g: Oats, \nPineapple, \nTomatoes, \nPasta.',
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
                            width: 130,
                            child: Image.asset(
                              'assets/images/manual/checklist_icon.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            width: 130,
                            child: Image.asset(
                              'assets/images/manual/taskDate_stamp.png',
                            ),
                          ),
                          const SizedBox(
                            width: 130,
                            child: Text(
                              '8. Duration Setting. \nSet your timeline with From/To dates.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Quick Add Media.\n Your creative hub for rich content:',
                              style: TextStyle(
                                fontSize: 14,
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
                              'assets/images/manual/addTask.png',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 155,
                            height: 350,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(
                              'assets/images/manual/addMedia.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(
                            width: 120,
                            child: Text(
                              '''
  + Events : \nSchedule and track important occasions in your life.\n
  + Additional Tasks : Create quick action items linked to your entries.\n
  + Voice Notes : Record audio snippets for quick thoughts and reminders.\n
  + Time Stamps : \nMark exact moments with automatic or custom timing.\n
  + Text Entries : Document your ideas, reflections, and observations.\n
  + Photos : \nCapture and store visual memories directly in your entries.
                                        ''',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              iconFunc2: const Column(
                children: [
                  Icon(
                    Ionicons.bar_chart_outline,
                  ),
                  Text('Dashboard'),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            const ManualIcons(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              icon1: Icons.calendar_month_outlined,
              icon2: Icons.settings_outlined,
              manualheader: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                  ),
                  Text('Calendar'),
                ],
              ),
              iconFunc: Text('This is where the calender instruction will be'),
              iconFunc2: Column(
                children: [
                  Icon(
                    Icons.settings_outlined,
                  ),
                  Text('Settings'),
                ],
              ),
            ),
            const SizedBox(
              height: 30,
            ),
            ManualIcons(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              icon1: MdiIcons.checkboxMultipleMarkedOutline,
              icon2: Ionicons.bar_chart_outline,
              manualheader: Row(
                children: [
                  Icon(
                    MdiIcons.checkboxMultipleMarkedOutline,
                  ),
                  const Text('Habits'),
                ],
              ),
              iconFunc: const Center(
                child: Text('Here is where the Habits instruction will be'),
              ),
              iconFunc2: const Column(
                children: [
                  Icon(
                    Ionicons.bar_chart_outline,
                  ),
                  Text('Dashboard'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
