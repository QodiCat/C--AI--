import "dart:typed_data";
import "package:flutter/material.dart";
import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../data/wardrobe_repository.dart";
import "recognition_result_page.dart";

class UploadProcessingPage extends StatefulWidget {
  const UploadProcessingPage(
      {super.key,
      required this.image,
      required this.fileName,
      required this.contentType});
  final Uint8List image;
  final String fileName;
  final String contentType;
  @override
  State<UploadProcessingPage> createState() => _UploadProcessingPageState();
}

class _UploadProcessingPageState extends State<UploadProcessingPage> {
  late final _repository =
      WardrobeRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  String? _error;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  Future<void> _upload() async {
    setState(() => _error = null);
    try {
      final uri = await _repository.uploadImage(
          widget.image, widget.fileName, widget.contentType);
      final candidate = await _repository.recognizeImage(uri);
      final cutoutUrl =
          await _repository.resolveImage(candidate["cutoutImageUrl"] as String);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => RecognitionResultPage(
                  image: widget.image,
                  originalImageUri: uri,
                  candidate: candidate,
                  cutoutUrl: cutoutUrl)));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = "上传失败，请检查网络后重试");
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text("正在上传与识别"),
          backgroundColor: const Color(0xFFFAF8F4)),
      body: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("多层处理，稍等片刻", style: TextStyle(color: Color(0xFF8C877F))),
            const SizedBox(height: 22),
            _ProgressTile(image: widget.image, title: "上传中", value: null),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.auto_awesome, title: "AI识别中", value: null),
            const SizedBox(height: 12),
            const _ProgressTile(
                icon: Icons.content_cut, title: "智能抠图", value: null),
            const Spacer(),
            if (_error != null) ...[
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: _upload,
                  icon: const Icon(Icons.refresh),
                  label: const Text("重新上传")),
            ] else
              const Center(
                  child: Text("识别完成后将自动进入确认页",
                      style: TextStyle(color: Color(0xFF8C877F)))),
            const SizedBox(height: 28),
          ])));
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile(
      {this.image, this.icon, required this.title, required this.value});
  final Uint8List? image;
  final IconData? icon;
  final String title;
  final double? value;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAE5DD))),
      child: Row(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
                width: 72,
                height: 72,
                child: image != null
                    ? Image.memory(image!, fit: BoxFit.cover)
                    : ColoredBox(
                        color: const Color(0xFFF0EAE2),
                        child: Icon(icon, color: const Color(0xFFA28C73))))),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 11),
          LinearProgressIndicator(
              value: value,
              color: const Color(0xFF718867),
              backgroundColor: const Color(0xFFE6E3DD),
              borderRadius: BorderRadius.circular(4))
        ])),
        const SizedBox(width: 12),
        Text(value == null ? "处理中" : "${(value! * 100).round()}%",
            style: const TextStyle(color: Color(0xFF858078)))
      ]));
}
