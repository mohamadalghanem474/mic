import 'dart:io';

import 'package:flutter/foundation.dart';

class FileService {
 static Future<void> saveAudioWav(List<int> audioData, String path) async {
    if (audioData.isEmpty) {
      debugPrint("No audio data to save.");
      return;
    }

    final filePath = '$path/mic_${DateTime.now().millisecondsSinceEpoch}.wav';

    final byteData = Uint8List.fromList(audioData);

    try {
      final wavFile = File(filePath);
      if (await wavFile.exists()) {
        await wavFile.delete();
      }

      final randomAccessFile = await wavFile.open(mode: FileMode.write);

      await _writeWavHeader(randomAccessFile, byteData.length);
      await randomAccessFile.writeFrom(byteData);
      await randomAccessFile.close();
      debugPrint("Audio data saved to: $filePath");
    } catch (e) {
      debugPrint("Error writing file: $e");
    }
  }

 static Future _writeWavHeader(RandomAccessFile outputStream, int dataSize) async {
    const int sampleRate = 44100;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;

    await outputStream.writeByte(0x52); // 'R'
    await outputStream.writeByte(0x49); // 'I'
    await outputStream.writeByte(0x46); // 'F'
    await outputStream.writeByte(0x46); // 'F'
    await _writeInt32(outputStream, dataSize + 36);
    await outputStream.writeByte(0x57); // 'W'
    await outputStream.writeByte(0x41); // 'A'
    await outputStream.writeByte(0x56); // 'V'
    await outputStream.writeByte(0x45); // 'E'

    await outputStream.writeByte(0x66); // 'f'
    await outputStream.writeByte(0x6D); // 'm'
    await outputStream.writeByte(0x74); // 't'
    await outputStream.writeByte(0x20); // ' '
    await _writeInt32(outputStream, 16);
    await _writeInt16(outputStream, 1);
    await _writeInt16(outputStream, numChannels);
    await _writeInt32(outputStream, sampleRate);
    await _writeInt32(outputStream, byteRate);
    await _writeInt16(outputStream, blockAlign);
    await _writeInt16(outputStream, bitsPerSample);

    await outputStream.writeByte(0x64); // 'd'
    await outputStream.writeByte(0x61); // 'a'
    await outputStream.writeByte(0x74); // 't'
    await outputStream.writeByte(0x61); // 'a'
    await _writeInt32(outputStream, dataSize);
  }

 static Future<void> _writeInt32(RandomAccessFile outputStream, int value) async {
    final byteData = ByteData(4);
    byteData.setInt32(0, value, Endian.little);
    await outputStream.writeFrom(byteData.buffer.asUint8List());
  }

 static Future<void> _writeInt16(RandomAccessFile outputStream, int value) async {
    final byteData = ByteData(2);
    byteData.setInt16(0, value, Endian.little);
    await outputStream.writeFrom(byteData.buffer.asUint8List());
  }
}
