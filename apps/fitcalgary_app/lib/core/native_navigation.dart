import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Client-review opt-in until the material change is visually approved.
/// Unsupported Apple versions and Android retain the verified Flutter control.
class NativeFitNavigation extends StatefulWidget {
  const NativeFitNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.fallback,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget fallback;

  @override
  State<NativeFitNavigation> createState() => _NativeFitNavigationState();
}

class _NativeFitNavigationState extends State<NativeFitNavigation> {
  late final Future<bool> supported;
  MethodChannel? channel;
  double nativeHeight = 68;

  void updateHeight(dynamic value) {
    if (!mounted || value is! num || !value.isFinite || value < 68) return;
    if (value.toDouble() != nativeHeight) {
      setState(() => nativeHeight = value.toDouble());
    }
  }

  @override
  void initState() {
    super.initState();
    supported = detectSupport();
  }

  Future<bool> detectSupport() async {
    if (!const bool.fromEnvironment('NATIVE_IOS_NAVIGATION') ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      return await const MethodChannel('fitcalgary/material')
              .invokeMethod<bool>('supportsNativeNavigation') ==
          true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant NativeFitNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      channel
          ?.invokeMethod<void>('setSelectedIndex', widget.selectedIndex)
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: supported,
    builder: (context, snapshot) => snapshot.data != true
        ? widget.fallback
        : SizedBox(
            height: math.max(
              nativeHeight,
              44 + MediaQuery.textScalerOf(context).scale(12) * 2,
            ),
            child: UiKitView(
              viewType: 'fitcalgary/navigation',
              creationParams: {'selectedIndex': widget.selectedIndex},
              creationParamsCodec: const StandardMessageCodec(),
              onPlatformViewCreated: (id) {
                channel = MethodChannel('fitcalgary/navigation/$id');
                channel!.setMethodCallHandler((call) async {
                  if (call.method == 'heightChanged') {
                    updateHeight(call.arguments);
                    return;
                  }
                  if (!mounted || call.method != 'select') return;
                  final index = call.arguments;
                  if (index is int && index >= 0 && index < 5) {
                    widget.onSelected(index);
                  }
                });
                channel!
                    .invokeMethod<num>('preferredHeight')
                    .then(updateHeight)
                    .catchError((Object _) {});
                channel!
                    .invokeMethod<void>(
                      'setSelectedIndex',
                      widget.selectedIndex,
                    )
                    .catchError((Object _) {});
              },
            ),
          ),
  );
}
