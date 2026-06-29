import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ImageCropperDialog extends StatefulWidget {
  final String imageBase64;
  const ImageCropperDialog({super.key, required this.imageBase64});

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  double _zoom = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() {
      setState(() {
        _zoom = _transformationController.value.getMaxScaleOnAxis();
      });
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _submitCrop() async {
    try {
      // Brief delay to allow rendering pipeline to catch up
      await Future.delayed(const Duration(milliseconds: 100));
      
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List bytes = byteData.buffer.asUint8List();
      final String croppedBase64 = 'data:image/png;base64,${base64Encode(bytes)}';

      if (mounted) {
        Navigator.pop(context, croppedBase64);
      }
    } catch (e) {
      debugPrint("Crop error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final base64String = widget.imageBase64.split(',').last;
    final imageBytes = base64Decode(base64String);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1C1917),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white10),
        ),
        title: const Text(
          'تنظیم تصویر آواتار',
          style: TextStyle(
            fontFamily: 'serif',
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'با کشیدن تصویر آن را جابجا کنید و برای زوم از دکمه‌های زیر یا حرکت دو انگشت استفاده کنید.',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'serif'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Outer circular mask
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  width: 160,
                  height: 160,
                  color: Colors.black,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(50),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Zoom controls slider
            Row(
              children: [
                const Icon(Icons.zoom_out, color: Colors.white54, size: 18),
                Expanded(
                  child: Slider(
                    value: _zoom.clamp(0.5, 4.0),
                    min: 0.5,
                    max: 4.0,
                    activeColor: const Color(0xFFD4AF37),
                    inactiveColor: Colors.white10,
                    onChanged: (val) {
                      setState(() {
                        _zoom = val;
                        final translation = _transformationController.value.getTranslation();
                        _transformationController.value = Matrix4.identity()
                          ..translate(translation.x, translation.y)
                          ..scale(val);
                      });
                    },
                  ),
                ),
                const Icon(Icons.zoom_in, color: Colors.white54, size: 18),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            onPressed: _submitCrop,
            child: const Text('ثبت برش', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
