import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class LieDetectorScreen extends StatefulWidget {
  const LieDetectorScreen({super.key});

  @override
  State<LieDetectorScreen> createState() => _LieDetectorScreenState();
}

class _LieDetectorScreenState extends State<LieDetectorScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;

  String _statusText = "آماده اسکن...";
  bool _isScanning = false;
  bool _scanComplete = false;
  int _stressLevel = 0;
  String _verdict = "";

  late AnimationController _animationController;

  final List<String> _funnyMessages = [
    "در حال تحلیل مردمک چشم...",
    "اندازه‌گیری ضربان قلب...",
    "بررسی لرزش‌های دست...",
    "تحلیل قطرات عرق روی پیشانی...",
    "ارتباط با سازمان‌های جاسوسی...",
    "استخراج الگوهای دروغ‌گویی..."
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Prefer front camera
        final frontCamera = _cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _controller = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _scanComplete = false;
      _statusText = "آماده‌سازی سنسورها...";
    });

    final rand = Random();

    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _statusText = _funnyMessages[rand.nextInt(_funnyMessages.length)];
      });
    }

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Generate result
    _stressLevel = rand.nextInt(41) + 60; // 60 to 100%
    if (_stressLevel > 85) {
      _verdict = "قطعا داره دروغ میگه!";
    } else if (_stressLevel > 70) {
      _verdict = "به شدت مشکوک!";
    } else {
      _verdict = "استرس داره، شاید هم راست میگه!";
    }

    setState(() {
      _isScanning = false;
      _scanComplete = true;
      _statusText = "اسکن کامل شد!";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF151211),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFD4AF37)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'دستگاه دروغ‌سنج',
            style: TextStyle(
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              color: Color(0xFFE6DFD3),
              letterSpacing: 1.5,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Camera frame
              Container(
                width: 300,
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isScanning
                        ? Colors.red
                        : const Color(0xFFD4AF37).withOpacity(0.5),
                    width: 3,
                  ),
                  boxShadow: [
                    if (_isScanning)
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isCameraInitialized && _controller != null)
                        CameraPreview(_controller!)
                      else
                        const Center(
                          child: Icon(Icons.camera_alt, color: Colors.white24, size: 50),
                        ),

                      // Scanning Animation Overlay
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Positioned(
                              top: _animationController.value * 380,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Target reticle
                      if (_isScanning || _scanComplete)
                        Center(
                          child: Icon(
                            Icons.filter_center_focus,
                            size: 100,
                            color: Colors.red.withOpacity(0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Status Text
              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'serif',
                  color: _isScanning ? Colors.redAccent : Colors.white70,
                  fontWeight: _isScanning ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              const SizedBox(height: 20),

              // Result display
              if (_scanComplete)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2523),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'میزان استرس: %$_stressLevel',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _verdict,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Action Button
              if (!_isScanning)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  onPressed: _isCameraInitialized ? _startScan : null,
                  icon: Icon(_scanComplete ? Icons.refresh : Icons.radar),
                  label: Text(
                    _scanComplete ? 'اسکن مجدد' : 'شروع اسکن چهره',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
