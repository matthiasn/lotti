import 'package:lotti/features/manual/task/domain/models/tasks_model.dart';

class TaskManualRepository {
  List<TaskManual> getManualContent() {
    return [
      TaskManual(
        title: 'Search.',
        steps: [
          StepDetail(
            guideText:
                'Navigate through your tasks effortlessly with the search function.',
          ),
        ],
        imagePath: 'assets/images/manual/src_icon.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Filter',
        steps: [
          StepDetail(
            guideText: 'Organize your view by filtering tasks your way',
          ),
        ],
        imagePath: 'assets/images/manual/filter_icon1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Add task',
        steps: [
          StepDetail(
            guideText:
                'Your gateway to task creation, revealing these powerful options:',
          ),
        ],
        imagePath: 'assets/images/manual/addTask.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Starred',
        steps: [
          StepDetail(
            guideText: 'Mark standout tasks that deserve special attention.\n',
          ),
          StepDetail(
            guideText: 'Highlight tasks that need follow-up or special focus.\n',
          ),
          StepDetail(
            guideText: 'Actions for managing tasks',
            innerDetail: true, innerImagePath: 'assets/images/manual/action_opt1.png',
          ),
        ],
        imagePath: 'assets/images/manual/starred_icon1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Task Name',
        steps: [
          StepDetail(
            guideText:
                '1. Task Name Field e.g. "Plan weekly grocery shopping".',
          ),
        ],
        imagePath: 'assets/images/manual/taskname_icon1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Time Estimate',
        steps: [
          StepDetail(
            guideText: '2. Time Estimate. e.g. 01:30 hours.',
          ),
        ],
        imagePath: 'assets/images/manual/taskTime_stamp1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Status Tracker',
        steps: [
          StepDetail(
            guideText: '3. Status Tracker Track progress:',
          ),
          StepDetail(
            guideText: 'Open → Groomed → In Progress → Complete',
            innerDetail: true,
          ),
        ],
        imagePath: 'assets/images/manual/task_status.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Category Management',
        steps: [
          StepDetail(
            guideText:
                '4. Category Management. \n- Select existing or create new \n- Pick your color \n- e.g. House Chores',
          ),
          StepDetail(
            guideText:
                '5. Color Picker \n- Choose custom color \n- Personalize categories \n- Visual organization',
          ),
        ],
        imagePath: 'assets/images/manual/setCate_icon.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Smart Notes',
        steps: [
          StepDetail(
            guideText: '6. Smart Notes.',
          ),
        ],
        imagePath: 'assets/images/manual/taskNote_icon1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Checklist',
        steps: [
          StepDetail(
            guideText: '7. Interactive Checklists.',
            innerDetail: true,
          ),
        ],
        imagePath: 'assets/images/manual/checklist_icon1.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Duration Setting',
        steps: [
          StepDetail(
            guideText: '8. Duration Setting.',
            innerDetail: true,
          ),
          StepDetail(
            guideText: 'Set your timeline with From/To dates.',
          ),
        ],
        imagePath: 'assets/images/manual/taskDate_stamp1.png',
        imageFirst: true,
      ),
      TaskManual(
        title: 'Attachments',
        steps: [
          StepDetail(
            guideText: 'Quick Add Media.',
            innerDetail: true,
          ),
          StepDetail(
            guideText: 'Your creative hub for rich content:',
          ),
        ],
        imagePath: 'assets/images/manual/addTask.png',
        imageFirst: false,
      ),
      TaskManual(
        title: 'Add Media',
        steps: [
          StepDetail(
            guideText:
                '+ Events : \nSchedule and track important occasions in your life.',
            innerDetail: true,
          ),
          StepDetail(
            guideText:
                '+ Additional Tasks : Create quick action items linked to your entries.',
            innerDetail: true,
          ),
          StepDetail(
            guideText:
                '+ Voice Notes : Record audio snippets for quick thoughts and reminders.',
            innerDetail: true,
          ),
          StepDetail(
            guideText:
                '+ Time Stamps : \nMark exact moments with automatic or custom timing.',
            innerDetail: true,
          ),
          StepDetail(
            guideText:
                '+ Text Entries : Document your ideas, reflections, and observations.',
            innerDetail: true,
          ),
          StepDetail(
            guideText:
                '+ Photos : \nCapture and store visual memories directly in your entries.',
            innerDetail: true,
          ),
        ],
        imagePath: 'assets/images/manual/addMedia1.png',
        imageFirst: true,
      ),
    ];
  }
}
