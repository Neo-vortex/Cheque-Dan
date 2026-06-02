import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../core/constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChequeYoloScannerScreen
//
// Opens the camera via YOLOView, overlays the best detection bounding-box,
// and lets the user tap "Capture" to crop just the cheque region and return
// it as a saved image path.
//
// Usage:
//   final String? path = await Navigator.push<String>(
//     context,
//     MaterialPageRoute(builder: (_) => const ChequeYoloScannerScreen()),
//   );
//   if (path != null) { /* use cropped image */ }
// ─────────────────────────────────────────────────────────────────────────────

class ChequeYoloScannerScreen extends StatefulWidget {
  /// Flutter asset path to your TFLite model, e.g.
  /// 'assets/models/cheque_detect.tflite'
  final String modelAssetPath;

  /// Confidence threshold (0‥1) below which detections are ignored.
  final double confidenceThreshold;

  const ChequeYoloScannerScreen({
    super.key,
    this.modelAssetPath = 'assets/models/cheque_detect.tflite',
    this.confidenceThreshold = 0.45,
  });

  @override
  State<ChequeYoloScannerScreen> createState() =>
      _ChequeYoloScannerScreenState();
}

class _ChequeYoloScannerScreenState extends State<ChequeYoloScannerScreen>
    with TickerProviderStateMixin {
  // ── YOLO ────────────────────────────────────────────────────────────────────
  final YOLOViewController _yoloController = YOLOViewController();

  /// Best detection from the last frame; null if nothing found yet.
  YOLOResult? _bestDetection;

  /// Live preview widget size – captured via LayoutBuilder.
  Size _previewSize = Size.zero;

  // ── State ───────────────────────────────────────────────────────────────────
  bool _isCapturing = false;
  bool _modelReady = false;

  // ── Pulse animation for the bounding box ────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── RepaintBoundary key – used to screenshot the camera frame ────────────────
  final GlobalKey _cameraKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── onResult callback from YOLOView ──────────────────────────────────────────
  // onResult receives List<YOLOResult>; each YOLOResult has:
  //   - double confidence        (non-nullable)
  //   - Rect boundingBox         (pixel coords inside the view)
  //   - Rect normalizedBox       (0‥1 coords)
  //   - String className
  void _onResults(List<YOLOResult> results) {
    if (!mounted) return;

    YOLOResult? best;
    double bestConf = widget.confidenceThreshold;

    for (final r in results) {
      if (r.confidence > bestConf) {
        bestConf = r.confidence;
        best = r;
      }
    }

    setState(() {
      _bestDetection = best;
      _modelReady = true;
    });
  }

  // ── Capture ───────────────────────────────────────────────────────────────────
  Future<void> _capture() async {
    if (_isCapturing) return;
    if (_bestDetection == null) {
      _showSnack('هیچ چکی پیدا نشد – لطفاً دوربین را تنظیم کنید');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);

    try {
      // 1. Screenshot the camera preview via the RepaintBoundary.
      final boundary = _cameraKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('render boundary not found');

      final ui.Image fullImage = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('failed to encode image');

      // 2. Decode so we can crop.
      final Uint8List fullPng = byteData.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(fullPng);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image decoded = frame.image;

      final int imgW = decoded.width;
      final int imgH = decoded.height;

      // 3. normalizedBox holds [0,1] coords – scale to screenshot pixel space.
      //    pixelRatio: 3.0 above means screenshot is 3× the widget size.
      final Rect norm = _bestDetection!.normalizedBox;
      const double pad = 0.012; // 1.2 % padding around the cheque

      final double l = ((norm.left   - pad).clamp(0.0, 1.0) * imgW);
      final double t = ((norm.top    - pad).clamp(0.0, 1.0) * imgH);
      final double r = ((norm.right  + pad).clamp(0.0, 1.0) * imgW);
      final double b = ((norm.bottom + pad).clamp(0.0, 1.0) * imgH);

      final int cropW = (r - l).round().clamp(1, imgW);
      final int cropH = (b - t).round().clamp(1, imgH);

      // 4. Crop using a Canvas.
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.drawImageRect(
        decoded,
        Rect.fromLTWH(l, t, cropW.toDouble(), cropH.toDouble()),
        Rect.fromLTWH(0, 0, cropW.toDouble(), cropH.toDouble()),
        Paint(),
      );
      final ui.Image cropped =
      await recorder.endRecording().toImage(cropW, cropH);

      final ByteData? croppedBytes =
      await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (croppedBytes == null) throw Exception('failed to encode crop');

      // 5. Save to temp file and pop with path.
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/cheque_scan_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(croppedBytes.buffer.asUint8List());

      if (mounted) Navigator.of(context).pop(file.path);
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showSnack('خطا در تصویربرداری: $e');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: AppColors.returned,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera + YOLO ──────────────────────────────────────────────────
          RepaintBoundary(
            key: _cameraKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final sz =
                  Size(constraints.maxWidth, constraints.maxHeight);
                  if (sz != _previewSize) {
                    setState(() => _previewSize = sz);
                  }
                });
                return YOLOView(
                  modelPath: widget.modelAssetPath,
                  task: YOLOTask.detect,
                  controller: _yoloController,
                  onResult: _onResults,
                  confidenceThreshold: widget.confidenceThreshold,
                  iouThreshold: 0.45,
                  // Disable the built-in overlay so we draw our own
                  showOverlays: false,
                );
              },
            ),
          ),

          // ── Our bounding-box overlay ───────────────────────────────────────
          if (_bestDetection != null && _previewSize != Size.zero)
            _BoundingBoxOverlay(
              // normalizedBox gives [0,1] coords relative to the widget size
              normalizedBox: _bestDetection!.normalizedBox,
              previewSize: _previewSize,
              pulse: _pulseAnimation,
            ),

          // ── Top bar ────────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _TopBar(onClose: () => Navigator.of(context).pop()),
            ),
          ),

          // ── Guide message ──────────────────────────────────────────────────
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _GuideMessage(
              modelReady: _modelReady,
              detected: _bestDetection != null,
            ),
          ),

          // ── Bottom capture bar ─────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _BottomBar(
                detected: _bestDetection != null,
                isCapturing: _isCapturing,
                onCapture: _capture,
                confidence: _bestDetection?.confidence,
              ),
            ),
          ),

          // ── Capture loading overlay ────────────────────────────────────────
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryLight),
                    SizedBox(height: 16),
                    Text(
                      'در حال پردازش تصویر...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bounding-box overlay
// ─────────────────────────────────────────────────────────────────────────────

class _BoundingBoxOverlay extends StatelessWidget {
  final Rect normalizedBox; // values in [0,1]
  final Size previewSize;
  final Animation<double> pulse;

  const _BoundingBoxOverlay({
    required this.normalizedBox,
    required this.previewSize,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final double l = normalizedBox.left   * previewSize.width;
    final double t = normalizedBox.top    * previewSize.height;
    final double w = normalizedBox.width  * previewSize.width;
    final double h = normalizedBox.height * previewSize.height;

    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) => CustomPaint(
        size: previewSize,
        painter: _BoxPainter(
          rect: Rect.fromLTWH(l, t, w, h),
          scale: pulse.value,
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  final Rect rect;
  final double scale;

  const _BoxPainter({required this.rect, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final center = rect.center;
    final scaled = Rect.fromCenter(
      center: center,
      width: rect.width * scale,
      height: rect.height * scale,
    );

    // Dim outside the box.
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scaled, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outer, Paint()..color = Colors.black.withOpacity(0.35));

    // Green border.
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaled, const Radius.circular(8)),
      Paint()
        ..color = AppColors.primaryLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Corner brackets.
    const double cs = 18;
    final cp = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(dx, 0), cp);
      canvas.drawLine(o, o + Offset(0, dy), cp);
    }

    corner(scaled.topLeft, cs, cs);
    corner(scaled.topRight, -cs, cs);
    corner(scaled.bottomLeft, cs, -cs);
    corner(scaled.bottomRight, -cs, -cs);
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.rect != rect || old.scale != scale;
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          const Expanded(
            child: Text(
              'اسکن چک',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guide message chip
// ─────────────────────────────────────────────────────────────────────────────

class _GuideMessage extends StatelessWidget {
  final bool modelReady;
  final bool detected;
  const _GuideMessage({required this.modelReady, required this.detected});

  @override
  Widget build(BuildContext context) {
    final String msg;
    final Color bg;

    if (!modelReady) {
      msg = 'در حال بارگذاری مدل...';
      bg = Colors.black54;
    } else if (detected) {
      msg = 'چک پیدا شد – برای گرفتن عکس لمس کنید';
      bg = AppColors.primary.withOpacity(0.85);
    } else {
      msg = 'دوربین را روی چک نگه دارید';
      bg = Colors.black54;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(msg),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            msg,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom capture bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool detected;
  final bool isCapturing;
  final VoidCallback onCapture;
  final double? confidence;

  const _BottomBar({
    required this.detected,
    required this.isCapturing,
    required this.onCapture,
    this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detected && confidence != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified,
                      size: 14, color: AppColors.primaryLight),
                  const SizedBox(width: 4),
                  Text(
                    'اطمینان: ${(confidence! * 100).toStringAsFixed(0)}٪',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: isCapturing ? null : onCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: detected
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.3),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: detected
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
                    : [],
              ),
              child: isCapturing
                  ? const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
                  : const Icon(Icons.camera_alt,
                  color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
