import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../application/app_controller.dart';
import '../../ai/ai_client.dart';
import '../../platform/pcm_audio.dart';
import 'dt_controls.dart';
import 'dt_sheet.dart';

Future<String?> showVoiceInput(BuildContext context) =>
    showDtSheet<String>(context: context, builder: (_) => const _VoiceInput());

class _VoiceInput extends ConsumerStatefulWidget {
  const _VoiceInput();
  @override
  ConsumerState<_VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends ConsumerState<_VoiceInput>
    with WidgetsBindingObserver {
  final _recorder = AudioRecorder();
  final _abort = Completer<void>();
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Timer? _timer;
  bool _recording = false, _busy = false, _starting = false;
  int _seconds = 0;
  String? _error;
  Uint8List? _wav;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording) unawaited(_cancel());
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    await _recorder.cancel();
    await _subscription?.cancel();
    _pcm.clear();
    if (mounted) {
      setState(() {
        _recording = false;
        _busy = false;
      });
    }
  }

  Future<void> _start() async {
    if (_busy || _starting || _recording) return;
    setState(() {
      _starting = true;
      _error = null;
      _wav = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        throw const AiClientException('需要麦克风权限才能录音，你也可以直接打字。');
      }
      if (!mounted) return;
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      _pcm.clear();
      _subscription = stream.listen(
        (chunk) {
          if (_pcm.length + chunk.length > 4 * 1024 * 1024) {
            unawaited(_finish());
          } else {
            _pcm.add(chunk);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _error = '麦克风被中断，请重新录制。');
          unawaited(_cancel());
        },
      );
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 110) unawaited(_finish());
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiClientException
              ? error.message
              : '无法启动麦克风，请检查权限或浏览器 HTTPS 环境。',
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _finish() async {
    if (_busy || !_recording) return;
    setState(() {
      _busy = true;
      _recording = false;
      _error = null;
    });
    _timer?.cancel();
    try {
      await _recorder.stop();
      await _subscription?.cancel();
      _wav = pcmToWav(_pcm.takeBytes());
      await _recognize();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiClientException
              ? error.message
              : '录音未完成，请重新录制。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recognize() async {
    final wav = _wav;
    if (wav == null) return;
    final text = await ref
        .read(appControllerProvider.notifier)
        .transcribeAudio(wav, abortTrigger: _abort.future);
    if (mounted) Navigator.pop(context, text);
  }

  @override
  void dispose() {
    if (!_abort.isCompleted) _abort.complete();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_recorder.dispose());
    _pcm.clear();
    _wav = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '语音输入',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const Text(
            '点击开始后才会录音。结束时发给 DeepSeek 转文字，结果先填入草稿，由你确认发送。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 22),
          Icon(_recording ? Icons.mic : Icons.mic_none, size: 42),
          const SizedBox(height: 10),
          Text(
            _busy
                ? '正在识别…'
                : _recording
                ? '正在录音 · $_seconds 秒 / 110 秒'
                : '录音仅在当前页面进行',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          DtButton(
            label: _recording ? '结束并转文字' : '开始录音',
            loadingText: _starting ? '正在打开麦克风…' : '正在识别…',
            status: _busy || _starting
                ? DtButtonStatus.loading
                : DtButtonStatus.idle,
            onPressed: _recording ? _finish : _start,
          ),
          if (_wav != null && _error != null)
            DtButton(
              label: '重试识别',
              variant: DtButtonVariant.secondary,
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await _recognize();
                      } catch (error) {
                        if (mounted) {
                          setState(
                            () => _error = error is AiClientException
                                ? error.message
                                : '识别失败，请重试。',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
            ),
          DtButton(
            label: '取消',
            variant: DtButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

Future<void> showReadAloud(BuildContext context, String text) =>
    showDtSheet<void>(
      context: context,
      builder: (_) => _ReadAloud(text: text),
    );

class _ReadAloud extends ConsumerStatefulWidget {
  const _ReadAloud({required this.text});
  final String text;
  @override
  ConsumerState<_ReadAloud> createState() => _ReadAloudState();
}

class _ReadAloudState extends ConsumerState<_ReadAloud> {
  final _player = AudioPlayer();
  final _abort = Completer<void>();
  Uint8List? _audio;
  String _voice = 'stella';
  bool _busy = false, _playing = false;
  String? _error;
  StreamSubscription<void>? _completion;
  @override
  void initState() {
    super.initState();
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    if (!_abort.isCompleted) _abort.complete();
    unawaited(_completion?.cancel());
    unawaited(_player.dispose());
    _audio = null;
    super.dispose();
  }

  Future<void> _action() async {
    if (_busy) return;
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_audio == null) {
        final audio = await ref
            .read(appControllerProvider.notifier)
            .synthesizeSpeech(
              widget.text,
              voice: _voice,
              abortTrigger: _abort.future,
            );
        if (mounted) setState(() => _audio = audio);
      } else {
        await _player.play(BytesSource(_audio!, mimeType: 'audio/wav'));
        if (mounted) setState(() => _playing = true);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiClientException
              ? error.message
              : '播放失败，请检查系统音量、浏览器播放权限后重试。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '朗读消息',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            '发送本条消息到 DeepSeek 合成语音；生成后点击播放，关闭面板即停止。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 16),
          DtSegmentedControl(
            labels: const ['Stella · 女声', 'Tide · 男声'],
            index: _voice == 'stella' ? 0 : 1,
            onChanged: (i) {
              if (_busy) return;
              unawaited(_player.stop());
              setState(() {
                _voice = i == 0 ? 'stella' : 'tide';
                _audio = null;
                _playing = false;
              });
            },
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          DtButton(
            label: _playing
                ? '停止朗读'
                : _audio == null
                ? '生成语音'
                : '播放语音',
            loadingText: '正在合成…',
            status: _busy ? DtButtonStatus.loading : DtButtonStatus.idle,
            onPressed: _action,
          ),
          DtButton(
            label: '关闭',
            variant: DtButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
