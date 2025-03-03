class TaskManual {
  final String title;
  final String steps;
  final String? imagePath;
  final bool? imageFirst;

  TaskManual({
    required this.title,
    required this.steps,
    this.imagePath,

    this.imageFirst,
  });
}
