import 'package:flutter/material.dart';
import '../tokens/app_space.dart';

/// App-level scaffold with an optional app bar and bottom bar.
///
/// Styling (padding, app bar) comes from the app theme; spacing
/// uses [AppSpace] tokens only.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.bottomBar,
    this.actions,
  });

  final String? title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final hasBar = title != null || actions != null;
    return Scaffold(
      appBar: hasBar
          ? AppBar(
              title: title != null ? Text(title!) : null,
              actions: actions,
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: body,
        ),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}
