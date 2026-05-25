import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';

/// QR scan icon button — tap to open camera scanner, result auto-fills field.
class QrScannerButton extends StatelessWidget {
  final Function(String) onScanned;

  const QrScannerButton({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
      tooltip: 'اسکن QR',
      onPressed: () async {
        HapticFeedback.lightImpact();
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => const _QrScanScreen(),
            fullscreenDialog: true,
          ),
        );
        if (result != null && result.isNotEmpty) {
          onScanned(result);
        }
      },
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _scanned = false;
  String? _lastValue;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _scanned = true;
    HapticFeedback.heavyImpact();
    setState(() => _lastValue = value);
    // Small delay so the user sees the detected frame
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.pop(context, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('اسکن شناسه صیادی'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _ctrl.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () => _ctrl.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),
          // Viewfinder overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _lastValue != null
                      ? AppColors.cleared
                      : AppColors.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Scan line animation
          _ScanLine(detected: _lastValue != null),
          // Bottom hint
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              _lastValue != null
                  ? '✓ کد شناسایی شد'
                  : 'QR کد شناسه صیادی را در مقابل دوربین قرار دهید',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _lastValue != null ? AppColors.cleared : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  final bool detected;
  const _ScanLine({required this.detected});

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.detected) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Positioned(
          top: MediaQuery.of(context).size.height / 2 -
              130 +
              (_anim.value * 260),
          left: MediaQuery.of(context).size.width / 2 - 130,
          child: Container(
            width: 260,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
