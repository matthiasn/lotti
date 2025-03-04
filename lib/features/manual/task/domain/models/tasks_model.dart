class TaskManual {
  TaskManual({
    required this.title,
    required this.steps,
    this.imagePath,
    this.imageFirst,
    this.innerDetail,
  });
  final String title;
  final String? imagePath;
  final bool? imageFirst;
  final bool? innerDetail;
  final List<StepDetail>? steps;
  
}
class StepDetail {

  StepDetail({required this.guideText, this.innerDetail = false});
  final String guideText;
  final bool innerDetail;
}
