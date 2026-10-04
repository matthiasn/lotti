### Fixed
- **Moving a task to another category could leave half of it behind.**
  Changing a task's category also moves its timers, recordings and linked
  tasks, and takes it out of a project in the old category. If the app quit
  or crashed partway through, the task was left in the new category with
  everything else still in the old one, and it stayed in the old project. The
  app now finishes an interrupted move the next time it starts.
- **A task's checklists kept their old category when the task moved.** New
  checklist items took the old category too. Checklists and their items now
  move with the task, unless another task also shows them.
