import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../design/components/app_scaffold.dart';
import '../../design/tokens/app_space.dart';

/// In-app network diagnostics: DNS, TCP, and HTTPS checks against
/// [Config.apiBaseUrl]. Auto-runs on open; safe to re-run offline.
class NetworkDiagnosticsScreen extends StatefulWidget {
  const NetworkDiagnosticsScreen({super.key});

  @override
  State<NetworkDiagnosticsScreen> createState() =>
      _NetworkDiagnosticsScreenState();
}

class _CheckResult {
  const _CheckResult({required this.ok, required this.detail});

  /// Null while the check is still running.
  final bool? ok;
  final String detail;
}

class _NetworkDiagnosticsScreenState extends State<NetworkDiagnosticsScreen> {
  static const _timeout = Duration(seconds: 10);
  static const _bodySnippetMax = 200;

  _CheckResult? _dns;
  _CheckResult? _tcp;
  _CheckResult? _https;
  bool _running = false;
  late final TextEditingController _hostController;

  String get _baseUrl => Config.apiBaseUrl;

  String get _host {
    try {
      return Uri.parse(_baseUrl).host;
    } catch (_) {
      return '';
    }
  }

  /// Hostname typed by the user; falls back to the baked API host.
  String get _effectiveHost {
    final typed = _hostController.text.trim();
    if (typed.isEmpty) return _host;
    if (typed.contains('://')) {
      try {
        final parsed = Uri.parse(typed);
        if (parsed.host.isNotEmpty) return parsed.host;
      } catch (_) {
        // Fall through to raw handling below.
      }
    }
    // Strip any path/query/fragment and optional port.
    final noPath = typed.split('/').first.trim();
    final noPort = noPath.split(':').first.trim();
    return noPort.isEmpty ? _host : noPort;
  }

  String get _effectiveBaseUrl {
    if (_effectiveHost == _host) return _baseUrl;
    final scheme = Uri.tryParse(_baseUrl)?.scheme;
    final s = (scheme == null || scheme.isEmpty) ? 'https' : scheme;
    return '$s://$_effectiveHost';
  }

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: _host);
    _runAll();
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _runAll() async {
    if (_running) return;
    setState(() {
      _running = true;
      _dns = null;
      _tcp = null;
      _https = null;
    });
    try {
      await _runDns();
      if (!mounted) return;
      await _runTcp();
      if (!mounted) return;
      await _runHttps();
    } catch (_) {
      // Individual checks already record their own errors; this guards
      // the sequencer itself so the screen never crashes.
    }
    if (!mounted) return;
    setState(() => _running = false);
  }

  Future<void> _runDns() async {
    final host = _effectiveHost;
    if (host.isEmpty) {
      if (!mounted) return;
      setState(
        () => _dns =
            const _CheckResult(ok: false, detail: 'Invalid base URL host'),
      );
      return;
    }
    try {
      final addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.any,
      ).timeout(_timeout);
      if (!mounted) return;
      if (addresses.isEmpty) {
        setState(
          () => _dns =
              const _CheckResult(ok: false, detail: 'No addresses found'),
        );
      } else {
        setState(
          () => _dns = _CheckResult(
            ok: true,
            detail: addresses.map((a) => a.address).join(', '),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _dns = _CheckResult(ok: false, detail: '$e'));
    }
  }

  Future<void> _runTcp() async {
    final host = _effectiveHost;
    if (host.isEmpty) {
      if (!mounted) return;
      setState(
        () => _tcp =
            const _CheckResult(ok: false, detail: 'Invalid base URL host'),
      );
      return;
    }
    final stopwatch = Stopwatch()..start();
    Socket? socket;
    try {
      socket = await Socket.connect(host, 443, timeout: _timeout);
      stopwatch.stop();
      if (!mounted) return;
      setState(
        () => _tcp = _CheckResult(
          ok: true,
          detail: 'Connected in ${stopwatch.elapsedMilliseconds} ms',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() => _tcp = _CheckResult(ok: false, detail: '$e'));
    } finally {
      try {
        socket?.destroy();
      } catch (_) {
        // Ignore close errors: result already recorded.
      }
    }
  }

  Future<void> _runHttps() async {
    final stopwatch = Stopwatch()..start();
    try {
      final dio = buildUnauthenticatedDio(baseUrl: _effectiveBaseUrl);
      final response = await dio.get<dynamic>('/health').timeout(_timeout);
      stopwatch.stop();
      if (!mounted) return;
      final body = '${response.data}';
      final snippet = body.length > _bodySnippetMax
          ? '${body.substring(0, _bodySnippetMax)}…'
          : body;
      setState(
        () => _https = _CheckResult(
          ok: true,
          detail:
              'HTTP ${response.statusCode} in ${stopwatch.elapsedMilliseconds} ms: $snippet',
        ),
      );
    } on DioException catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(
        () => _https = _CheckResult(
          ok: false,
          detail:
              'Dio error after ${stopwatch.elapsedMilliseconds} ms: ${e.response?.statusCode ?? e.type}: ${e.message ?? e}',
        ),
      );
    } catch (e) {
      stopwatch.stop();
      if (!mounted) return;
      setState(() => _https = _CheckResult(ok: false, detail: '$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'নেটওয়ার্ক টেস্ট / Network test',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              'API: $_baseUrl',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpace.l),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: 'example.com',
                      border: OutlineInputBorder(),
                    ),
                    autocorrect: false,
                    onSubmitted: (_) {
                      if (!_running) _runAll();
                    },
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                FilledButton(
                  onPressed: _running ? null : _runAll,
                  child: const Text('Test'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.l),
            _CheckTile(title: 'DNS', result: _dns),
            const SizedBox(height: AppSpace.m),
            _CheckTile(title: 'TCP :443', result: _tcp),
            const SizedBox(height: AppSpace.m),
            _CheckTile(title: 'HTTPS GET /health', result: _https),
            const SizedBox(height: AppSpace.xl),
            FilledButton.icon(
              onPressed: _running ? null : _runAll,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_running ? 'Running…' : 'Re-run'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.title, required this.result});

  final String title;
  final _CheckResult? result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = result;
    final Widget leading;
    final String detail;
    final Color? detailColor;
    if (r == null) {
      leading = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      detail = 'Running…';
      detailColor = scheme.onSurfaceVariant;
    } else if (r.ok == true) {
      leading = Icon(Icons.check_circle_outline, color: scheme.primary);
      detail = r.detail;
      detailColor = null;
    } else {
      leading = Icon(Icons.error_outline, color: scheme.error);
      detail = r.detail;
      detailColor = null;
    }
    return Card(
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: SelectableText(
          r == null ? detail : '${r.ok == true ? '✓' : '✗'} $detail',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: detailColor),
        ),
      ),
    );
  }
}
