import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_config.dart';
import '../data/wardrobe_repository.dart';
import '../models/wardrobe_item.dart';
import 'recognition_result_page.dart';

class BatchPhoto {
  BatchPhoto(this.bytes, this.name, this.contentType);
  final Uint8List bytes;
  final String name;
  final String contentType;
  String status = '等待处理';
  String? uri;
  String? cutoutUrl;
  Map<String, dynamic>? candidate;
  String? error;
  bool busy = false;
  bool saved = false;
  bool confirming = false;
}

class BatchUploadPage extends StatefulWidget {
  const BatchUploadPage({super.key, required this.photos, this.repository});
  final List<BatchPhoto> photos;
  final WardrobeRepository? repository;

  @override
  State<BatchUploadPage> createState() => _BatchUploadPageState();
}

class _BatchUploadPageState extends State<BatchUploadPage> {
  late final _repository = widget.repository ??
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  int _next = 0;

  @override
  void initState() {
    super.initState();
    _worker();
    _worker();
  }

  Future<void> _worker() async {
    while (mounted && _next < widget.photos.length) {
      final photo = widget.photos[_next++];
      await _process(photo);
    }
  }

  Future<void> _process(BatchPhoto photo) async {
    if (!mounted || photo.busy) return;
    setState(() {
      photo.busy = true;
      photo.error = null;
      photo.status = photo.uri == null ? '上传中' : '识别与抠图中';
    });
    try {
      photo.uri ??= await _repository.uploadImage(
          photo.bytes, photo.name, photo.contentType);
      if (!mounted) return;
      setState(() => photo.status = '识别与抠图中');
      photo.candidate ??= await _repository.recognizeImage(photo.uri!);
      photo.cutoutUrl = await _repository
          .resolveImage(photo.candidate!['cutoutImageUrl'] as String);
      if (mounted) setState(() => photo.status = '待确认');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          photo.error = e.message;
          photo.status = '处理失败';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          photo.error = '网络或图片处理失败，请重试';
          photo.status = '处理失败';
        });
      }
    } finally {
      if (mounted) setState(() => photo.busy = false);
    }
  }

  Future<void> _confirm(BatchPhoto photo) async {
    setState(() => photo.confirming = true);
    try {
      final result =
          await Navigator.of(context).push<WardrobeItem>(MaterialPageRoute(
              builder: (_) => RecognitionResultPage(
                    image: photo.bytes,
                    originalImageUri: photo.uri!,
                    candidate: photo.candidate!,
                    cutoutUrl: photo.cutoutUrl,
                    repository: _repository,
                  )));
      if (mounted && result != null) {
        setState(() {
          photo.saved = true;
          photo.status = '已保存';
        });
      }
    } finally {
      if (mounted) setState(() => photo.confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final processed = widget.photos
        .where((p) => !p.busy && (p.candidate != null || p.error != null))
        .length;
    final saved = widget.photos.where((p) => p.saved).length;
    return Scaffold(
      appBar: AppBar(title: const Text('批量上传与识别')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('已处理 $processed/${widget.photos.length} · 已保存 $saved 件'),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: processed / widget.photos.length),
              const SizedBox(height: 12),
              const Text('每张图片拍摄一件单品，识别完成后逐件确认保存。'),
            ])),
        Expanded(
            child: ListView.builder(
                itemCount: widget.photos.length,
                itemBuilder: (context, index) {
                  final photo = widget.photos[index];
                  return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Image.memory(photo.bytes,
                                    width: 72, height: 90, fit: BoxFit.cover),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          photo.candidate?['name'] as String? ??
                                              photo.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      Text(photo.status),
                                      if (photo.busy)
                                        const LinearProgressIndicator(),
                                      if (photo.error != null) ...[
                                        Text(photo.error!,
                                            style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error)),
                                        TextButton(
                                            onPressed:
                                                widget.photos.any((p) => p.busy)
                                                    ? null
                                                    : () => _process(photo),
                                            child: const Text('重试此图片')),
                                      ] else if (photo.candidate != null &&
                                          !photo.saved &&
                                          !photo.busy)
                                        FilledButton(
                                            onPressed: photo.confirming
                                                ? null
                                                : () => _confirm(photo),
                                            child: const Text('确认并保存')),
                                    ])),
                              ])));
                })),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('返回衣橱')))),
      ]),
    );
  }
}
