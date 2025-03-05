class TaskManual {
  TaskManual({
    required this.title,
    required this.steps,
    this.imagePath,
    this.imageFirst,
  });
  final String title;
  final String? imagePath;
  final bool? imageFirst;
  final List<StepDetail>? steps;
  
}
class StepDetail {
  StepDetail({required this.guideText, this.innerDetail = false, this.innerImagePath,});
  final String guideText;
  final bool innerDetail;
  final String? innerImagePath;

}


