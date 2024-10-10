import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'package:image_picker/image_picker.dart';

enum Options { none, imagev8 }

late List<CameraDescription> cameras;

main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late FlutterVision vision;
  Options option = Options.none;

  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeYoloModel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: task(option),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        backgroundColor: Colors.black12,
        foregroundColor: Colors.white,
        activeBackgroundColor: Colors.deepPurpleAccent,
        activeForegroundColor: Colors.white,
        visible: true,
        closeManually: false,
        curve: Curves.bounceIn,
        overlayColor: Colors.black,
        overlayOpacity: 0.5,
        buttonSize: const Size(56.0, 56.0),
        children: [
          SpeedDialChild(
            child: const Icon(Icons.camera),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            label: 'YoloV8 on Image',
            labelStyle: const TextStyle(fontSize: 18.0),
            onTap: () {
              setState(() {
                option = Options.imagev8;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget task(Options option) {
    if (option == Options.imagev8) {
      return YoloImageV8(vision: vision);
    }
    return const Center(child: Text("Choose Task"));
  }
}

class YoloImageV8 extends StatefulWidget {
  final FlutterVision vision;

  const YoloImageV8({super.key, required this.vision});

  @override
  _YoloImageV8State createState() => _YoloImageV8State();
}

class _YoloImageV8State extends State<YoloImageV8> {
  File? _imageFile;
  List<Map<String, dynamic>>? _yoloResults;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo != null) {
      setState(() {
        _imageFile = File(photo.path);
      });
      _runYoloOnImage();
    }
  }

  Future<void> _runYoloOnImage() async {
    if (_imageFile == null) return;

    Uint8List bytes = await _imageFile!.readAsBytes();
    final image = await decodeImageFromList(bytes);
    final results = await widget.vision.yoloOnImage(
      bytesList: bytes,
      imageHeight: image.height,
      imageWidth: image.width,
      iouThreshold: 0.8,
      confThreshold: 0.4,
      classThreshold: 0.5,
    );

    setState(() {
      _yoloResults = results.isNotEmpty ? results : null;
    });
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/model/labels.txt',
        modelPath: 'assets/model/yoloModel.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _imageFile != null
              ? Image.file(_imageFile!, width: 300, height: 300)
              : const Text("No image selected"),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _pickImage,
            child: const Text("Select Image"),
          ),
          const SizedBox(height: 20),
          _yoloResults != null
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: _yoloResults!.length,
                  itemBuilder: (context, index) {
                    final result = _yoloResults![index];
                    return ListTile(
                      title: Text("Object: ${result['label']}"),
                      subtitle: Text(
                          "Confidence: ${(result['confidence'] * 100).toStringAsFixed(2)}%"),
                    );
                  },
                )
              : const Text("No results found"),
        ],
      ),
    );
  }
}
