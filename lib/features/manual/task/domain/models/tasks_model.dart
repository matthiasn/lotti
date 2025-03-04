class TaskManual {
  TaskManual({
    required this.title,
    required this.steps,
    this.imagePath,
    this.imageFirst,
    this.innerDetail,
  });
  final String title;
  final String steps;
  final String? imagePath;
  final bool? imageFirst;
  final bool? innerDetail;
}
