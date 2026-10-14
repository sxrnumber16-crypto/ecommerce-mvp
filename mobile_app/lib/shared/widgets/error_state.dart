import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Maps backend / transport failures to friendly Bangla + English text.
///
/// Reads `error` from JSON error bodies when present; falls back to
/// status-code defaults. Never leaks raw stack traces to shoppers.
String friendlyError(
  Object e, {
  String fallback = 'কিছু ভুল হয়েছে / Something went wrong',
}) {
  if (e is DioException) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return 'ইন্টারনেট সংযোগ পরীক্ষা করুন / Check your internet connection';
    }
    final data = e.response?.data;
    final serverError =
        data is Map && data['error'] is String ? data['error'] as String : null;
    switch (e.response?.statusCode) {
      case 400:
        return serverError == 'validation'
            ? 'তথ্য সঠিক নয় / Please check the entered information'
            : (serverError ?? 'অনুরোধ সঠিক নয় / Bad request');
      case 401:
        return 'সেশন শেষ, আবার লগইন করুন / Session expired, please log in again';
      case 403:
        return 'অনুমতি নেই / You are not allowed to do this';
      case 404:
        return 'পাওয়া যায়নি / Not found';
      case 409:
        if (serverError == 'insufficient stock') {
          return 'স্টক শেষ / Insufficient stock for one or more items';
        }
        return serverError ?? 'দ্বন্দ্ব হয়েছে / Conflict, please retry';
      default:
        return serverError ?? fallback;
    }
  }
  return fallback;
}

/// Full-screen error placeholder with a retry button.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('আবার চেষ্টা করুন / Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
