import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wisely/health/health_service.dart';

class PhotoImportPage extends StatefulWidget {
  const PhotoImportPage({Key? key}) : super(key: key);

  @override
  State<PhotoImportPage> createState() => _PhotoImportPageState();
}

class _PhotoImportPageState extends State<PhotoImportPage> {
  late HealthService healthService;

  @override
  void initState() {
    super.initState();
    healthService = HealthService();
  }

  void _importPhotos() async {
    final ImagePicker _picker = ImagePicker();
    // final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    // final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    final List<XFile>? images = await _picker.pickMultiImage();
    print(images);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            OutlinedButton(
              onPressed: _importPhotos,
              child: const Text(
                'Import Photos',
                style: TextStyle(color: CupertinoColors.systemOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
