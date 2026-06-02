import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../../core/constants/app_colors.dart';

class ChequeYoloScannerScreen extends StatefulWidget {
  final String modelAssetPath;
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
  final YOLOViewController _yoloController = YOLOViewController();
  YOLOResult? _bestDetection;
  Size _previewSize = Size.zero;
  bool _isCapturing = false;
  bool _modelReady = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final GlobalKey _cameraKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // Force landscape for cheque scanning.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
    // Restore all orientations when leaving the scanner.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pulseController.dispose();
    super.dispose();
  }

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

  /// Expands a normalised [0,1] rect so the longer side grows by [expandFrac]
  /// on each of its two edges, and the shorter side grows by the same absolute
  /// amount (keeping the expansion visually balanced).
  Rect _expandBox(Rect norm, double expandFrac) {
    final double w = norm.width;
    final double h = norm.height;

    // Half-expansion for each edge of the longer side.
    final double longHalf  = (w >= h ? w : h) * expandFrac / 2;
    final double shortHalf = (w >= h ? h : w) * expandFrac / 2;

    final double dw = w >= h ? longHalf  : shortHalf;
    final double dh = w >= h ? shortHalf : longHalf;

    return Rect.fromLTRB(
      (norm.left   - dw).clamp(0.0, 1.0),
      (norm.top    - dh).clamp(0.0, 1.0),
      (norm.right  + dw).clamp(0.0, 1.0),
      (norm.bottom + dh).clamp(0.0, 1.0),
    );
  }

  Future<void> _capture() async {
    if (_isCapturing) return;
    if (_bestDetection == null) {
      _showSnack('هیچ چکی پیدا نشد – لطفاً دوربین را تنظیم کنید');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);

    try {
      // 1. Screenshot the camera preview.
      final boundary = _cameraKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('render boundary not found');

      final ui.Image fullImage = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await fullImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('failed to encode image');

      // 2. Decode.
      final Uint8List fullPng = byteData.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(fullPng);
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image decoded = frame.image;
      final int imgW = decoded.width;
      final int imgH = decoded.height;

      // 3. Expand the box: longer side gets +10 %, same absolute px on shorter side.
      final Rect expanded = _expandBox(_bestDetection!.normalizedBox, 0.10);

      final double l = expanded.left   * imgW;
      final double t = expanded.top    * imgH;
      final double r = expanded.right  * imgW;
      final double b = expanded.bottom * imgH;

      final int cropW = (r - l).round().clamp(1, imgW);
      final int cropH = (b - t).round().clamp(1, imgH);

      // 4. Crop.
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

      // 5. Save and return.
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
                  final sz = Size(constraints.maxWidth, constraints.maxHeight);
                  if (sz != _previewSize) setState(() => _previewSize = sz);
                });
                return YOLOView(
                  modelPath: widget.modelAssetPath,
                  task: YOLOTask.detect,
                  controller: _yoloController,
                  onResult: _onResults,
                  confidenceThreshold: widget.confidenceThreshold,
                  iouThreshold: 0.45,
                  showOverlays: false,
                );
              },
            ),
          ),

          // ── Bounding-box overlay (shows expanded box) ──────────────────────
          if (_bestDetection != null && _previewSize != Size.zero)
            _BoundingBoxOverlay(
              normalizedBox: _expandBox(_bestDetection!.normalizedBox, 0.10),
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
  final Rect normalizedBox;
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

    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(scaled, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outer, Paint()..color = Colors.black.withOpacity(0.35));

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaled, const Radius.circular(8)),
      Paint()
        ..color = AppColors.primaryLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

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
      msg = 'دوربین را به صورت افقی روی چک نگه دارید';
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
