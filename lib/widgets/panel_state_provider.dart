import 'package:flutter/material.dart';

// Provider to pass panel state to children
class PanelStateProvider extends InheritedWidget {
  final bool isPanelOpen;
  
  const PanelStateProvider({
    Key? key,
    required this.isPanelOpen,
    required Widget child,
  }) : super(key: key, child: child);
  
  static PanelStateProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PanelStateProvider>();
  }
  
  @override
  bool updateShouldNotify(PanelStateProvider oldWidget) {
    return isPanelOpen != oldWidget.isPanelOpen;
  }
}
