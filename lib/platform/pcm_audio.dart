import 'dart:convert';
import 'dart:typed_data';

/// Record PCM in memory on every platform, wrap once for the documented ASR
/// endpoint. No temporary audio file and no browser-only encoding assumptions.
Uint8List pcmToWav(Uint8List pcm, {int sampleRate = 16000, int channels = 1}) {
  if (pcm.isEmpty || pcm.length.isOdd) throw const FormatException('录音没有有效音频');
  final result = Uint8List(44 + pcm.length);
  final header = ByteData.sublistView(result);
  result.setRange(0, 4, ascii.encode('RIFF'));
  header.setUint32(4, result.length - 8, Endian.little);
  result.setRange(8, 16, ascii.encode('WAVEfmt '));
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * channels * 2, Endian.little);
  header.setUint16(32, channels * 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  result.setRange(36, 40, ascii.encode('data'));
  header.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}

/// Validate frame alignment and advertised byte lengths before uploading or
/// playing audio. Streaming WAV may use 0xffffffff as its unknown data length.
bool isCompletePcmWav(Uint8List bytes, {Duration? maxDuration}) {
  if (bytes.length < 44 ||
      ascii.decode(bytes.sublist(0, 4), allowInvalid: true) != 'RIFF' ||
      ascii.decode(bytes.sublist(8, 12), allowInvalid: true) != 'WAVE') {
    return false;
  }
  final data = ByteData.sublistView(bytes);
  final riffSize = data.getUint32(4, Endian.little);
  if (riffSize != 0xffffffff && riffSize + 8 > bytes.length) return false;
  int? rate, channels, alignment;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final tag = ascii.decode(
      bytes.sublist(offset, offset + 4),
      allowInvalid: true,
    );
    final length = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (tag == 'data') {
      final size = length == 0xffffffff ? bytes.length - start : length;
      if (rate == null ||
          channels == null ||
          alignment == null ||
          size <= 0 ||
          start + size > bytes.length ||
          size % alignment != 0) {
        return false;
      }
      return maxDuration == null ||
          size / (rate * alignment) <=
              maxDuration.inMicroseconds / Duration.microsecondsPerSecond;
    }
    if (start + length > bytes.length) return false;
    if (tag == 'fmt ') {
      if (length < 16 ||
          data.getUint16(start, Endian.little) != 1 ||
          data.getUint16(start + 14, Endian.little) != 16) {
        return false;
      }
      channels = data.getUint16(start + 2, Endian.little);
      rate = data.getUint32(start + 4, Endian.little);
      alignment = data.getUint16(start + 12, Endian.little);
      if (![1, 2].contains(channels) ||
          ![8000, 16000, 22050, 24000, 32000, 44100, 48000].contains(rate) ||
          alignment != channels * 2 ||
          data.getUint32(start + 8, Endian.little) != rate * alignment) {
        return false;
      }
    }
    offset = start + length + length % 2;
  }
  return false;
}
