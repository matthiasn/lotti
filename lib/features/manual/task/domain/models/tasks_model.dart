class TaskManual {
  final String title;
  final String steps;
  final String? imagePath;
  final double imageWidth;
  final bool? imageFirst;

  TaskManual({
    required this.title,
    required this.steps,
    this.imagePath,
    this.imageWidth = 110,
    this.imageFirst,

  });
}
