import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';

class TaskManualRepository {
  List<TaskManual> getManualContent() {
    return [
      TaskManual(
        title: 'Search.',
        steps:
            'Navigate through your tasks effortlessly with the search function.',
        imagePath: 'assets/images/manual/src_icon.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Filter',
        steps: 'Organize your view by filtering tasks your way',
        imagePath: 'assets/images/manual/filter_icon1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Add task',
        steps:
            'Your gateway to task creation, revealing these powerful options:',
        imagePath: 'assets/images/manual/addTask.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Starred',
        steps: '''
* Mark standout tasks that deserve special attention.

* Highlight tasks that need follow-up or special focus.

* Actions for managing tasks (?).
''',
        imagePath: 'assets/images/manual/starred_icon1.png',
        imageFirst: false,
        innerDetail: true,
      ),
      TaskManual(
        title: 'Task Name',
        steps: '1. Task Name Field e.g. "Plan weekly grocery shopping".',
        imagePath: 'assets/images/manual/taskname_icon1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Time Estimate',
        steps: '2. Time Estimate. e.g. 01:30 hours. (?)',
        imagePath: 'assets/images/manual/taskTime_stamp1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Status Tracker',
        steps:
            '3. Status Tracker Track progress: \nOpen → Groomed → In Progress → Complete (?)',
        imagePath: 'assets/images/manual/task_status.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Category Management',
        steps:
            '4. Category Management.(?) \n- Select existing or create new \n- Pick your color \n- e.g. House Chores\n\n5. Color Picker \n- Choose custom colors (?) \n- Personalize categories \n- Visual organization',
        imagePath: 'assets/images/manual/setCate_icon.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Smart Notes',
        steps: '6. Smart Notes.',
        imagePath: 'assets/images/manual/taskNote_icon1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Checklist',
        steps:
            '7. Interactive Checklists. (?) \ne.g: Oats, \nPineapple, \nTomatoes, \nPasta.',
        imagePath: 'assets/images/manual/checklist_icon1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Duration Setting',
        steps:
            '8. Duration Setting. (?) \nSet your timeline with From/To dates.',
        imagePath: 'assets/images/manual/taskDate_stamp1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Attachments',
        steps: 'Quick Add Media.\n Your creative hub for rich content:',
        imagePath: 'assets/images/manual/addTask.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Add Media',
        steps: '''
  + Events : \nSchedule and track important occasions in your life. (?)\n
  + Additional Tasks : Create quick action items linked to your entries. (?)\n
  + Voice Notes : Record audio snippets for quick thoughts and reminders. (?)\n
  + Time Stamps : \nMark exact moments with automatic or custom timing. (?)\n
  + Text Entries : Document your ideas, reflections, and observations. (?)\n
  + Photos : \nCapture and store visual memories directly in your entries. (?)
                                        ''',
        imagePath: 'assets/images/manual/addMedia1.png',
        imageFirst: true,
      ),
    ];
  }
}
