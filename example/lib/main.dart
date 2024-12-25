import 'package:flutter/material.dart';
import 'package:mic/mic.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.microphone.request();
  await Permission.manageExternalStorage.request();
  if (await Permission.microphone.isGranted && await Permission.manageExternalStorage.isGranted) {
    debugPrint('Permission granted');
    return;
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MicPlugin get micPlugin => MicPlugin.instance;
  MicState get micState => micPlugin.state.value;
  @override
  void initState() {
    super.initState();
    micPlugin.init();
    micPlugin.state.addListener(() {
      setState(() {});
    });
    micPlugin.stream.listen((audioData) {
      debugPrint('Audio data: ${audioData.length}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Text('Mic State: $micState'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            if (micPlugin.state.value != MicState.started) {
              await micPlugin.start();
            } else {
              await micPlugin.stop();
            }
          },
          child: micState == MicState.started ? const Icon(Icons.stop) : const Icon(Icons.mic),
        ),
      ),
    );
  }
}
