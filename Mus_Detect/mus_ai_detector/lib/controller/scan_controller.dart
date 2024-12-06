import 'package:camera/camera.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    initCamera();
    initTFLite();
  }

  @override
  void dispose() {
    super.dispose();
    cameraController.dispose();
  }

  late CameraController cameraController;
  late List<CameraDescription> cameras;

  var isCameraInitialized = false.obs;
  var cameraCount = 0;

  var x, y, w, h = 0.0;
  var label = "";

  initCamera() async {
    if (await Permission.camera.request().isGranted) {
      cameras = await availableCameras();

      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.max,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );
      await cameraController.initialize().then((value) {
        cameraCount = 0;
        cameraController.startImageStream((image) {
          cameraCount++;
          if (cameraCount % 90 == 0) {
            cameraCount = 0;
            objectDetector(image);
          }
          update();
        });
      });
      isCameraInitialized(true);
      update();
    } else {
      print("permission Denied");
    }
  }

  initTFLite() async {
    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
      isAsset: true,
      numThreads: 1,
      useGpuDelegate: false,
    );
  }

  objectDetector(CameraImage image) async {
    var detector = await Tflite.runModelOnFrame(
      bytesList: image.planes.map((e) {
        return e.bytes;
      }).toList(),
      asynch: true,
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 1,
      rotation: 90,
      threshold: 0.4,
    );

    if (detector != null && detector.isNotEmpty) {
      var ourDetectorObject = detector.first;
      var confidence = detector.first['confidenceInClass'];

      if (confidence != null && (confidence * 100) > 45) {
        label = detector.first['detectedClass']?.toString() ?? "Unknown";
        h = ourDetectorObject['rect']?['h'] ?? 0.0;
        w = ourDetectorObject['rect']?['w'] ?? 0.0;
        x = ourDetectorObject['rect']?['x'] ?? 0.0;
        y = ourDetectorObject['rect']?['y'] ?? 0.0;
        // log("Result is $detector");
      } else {
        print("Confidence value is null or less than 45.");
      }
      update();
    } else {
      print("Detector is null or empty.");
    }
  }
}
