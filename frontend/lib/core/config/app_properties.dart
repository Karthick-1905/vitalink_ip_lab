import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/constants/strings.dart';
import 'package:frontend/core/config/property_defaults.dart';

/// Public presentation data only. Authentication and clinical policy never use it.
class AppProperties extends ChangeNotifier with WidgetsBindingObserver {
  AppProperties({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              baseUrl: AppStrings.apiBaseUrl,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 4),
            ),
          );

  static final instance = AppProperties();
  String get cacheKey =>
      'public_app_properties_v1:${_client.options.baseUrl}:${AppStrings.apiPathPrefix}';
  final Dio _client;
  SharedPreferences? _preferences;
  Map<String, String> _properties = Map.of(propertyDefaults);
  int revision = 0;
  bool _initialized = false;
  Future<void>? _refreshing;
  String? _etag;
  DateTime? _lastAttempt;

  String text(String key, {Map<String, String> arguments = const {}}) {
    final value = _properties[key] ?? propertyDefaults[key] ?? key;
    return value.replaceAllMapped(
      RegExp(r'\{([a-zA-Z][a-zA-Z0-9_]*)\}'),
      (match) => arguments[match[1]] ?? match[0]!,
    );
  }

  Color color(String key) =>
      Color(int.parse(text(key).replaceFirst('#', 'FF'), radix: 16));

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      _preferences = await SharedPreferences.getInstance();
      final cached = _preferences!.getString(cacheKey);
      if (cached != null) {
        final payload = jsonDecode(cached);
        if (apply(payload) && payload['etag'] is String) {
          _etag = payload['etag'] as String;
        }
      }
    } catch (_) {
      /* Bundled defaults are always available. */
    }
    // Network availability must never block the login screen.
    unawaited(refresh());
  }

  /// Accept a whole compatible snapshot, never a partially validated update.
  bool apply(dynamic payload) {
    if (payload is! Map ||
        payload['schemaVersion'] != 1 ||
        payload['revision'] is! int ||
        payload['revision'] < revision ||
        payload['properties'] is! Map) {
      return false;
    }
    final next = Map<String, String>.of(propertyDefaults);
    final raw = payload['properties'] as Map;
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String || !propertyDefaults.containsKey(key)) continue;
      final value = entry.value;
      if (value is! String || value.length > 4000) return false;
      if (key.startsWith('theme.') &&
          !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
        return false;
      }
      if (key.startsWith('asset.') &&
          value != propertyDefaults[key] &&
          !RegExp(r'^brand-asset:[a-f0-9]{64}$').hasMatch(value)) {
        final uri = Uri.tryParse(value);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasFragment) {
          return false;
        }
      }
      List<String> placeholders(String input) => RegExp(
        r'\{([a-zA-Z][a-zA-Z0-9_]*)\}',
      ).allMatches(input).map((match) => match[1]!).toList()..sort();
      if (placeholders(value).join(',') !=
          placeholders(propertyDefaults[key]!).join(',')) {
        return false;
      }
      next[key] = value;
    }
    _properties = next;
    revision = payload['revision'] as int;
    notifyListeners();
    return true;
  }

  Future<void> refresh({bool force = false}) {
    if (_refreshing != null) {
      // A publication may have completed after an older request started.
      // Wait for that request, then fetch the newly published state.
      if (force) return _refreshing!.then((_) => refresh(force: true));
      return _refreshing!;
    }
    if (!force &&
        _lastAttempt != null &&
        DateTime.now().difference(_lastAttempt!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    _lastAttempt = DateTime.now();
    return _refreshing = _fetch().whenComplete(() => _refreshing = null);
  }

  Future<void> _fetch() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '${AppStrings.apiPathPrefix}/app-properties',
        options: Options(
          headers: {if (_etag != null) 'If-None-Match': _etag},
          validateStatus: (status) => status == 200 || status == 304,
        ),
      );
      if (response.statusCode == 304) return;
      final payload = response.data?['data'];
      if (apply(payload)) {
        _etag = response.headers.value('etag');
        await _preferences?.setString(
          cacheKey,
          jsonEncode({
            ...Map<String, dynamic>.from(payload as Map),
            if (_etag != null) 'etag': _etag,
          }),
        );
      }
    } catch (_) {
      /* Keep the last working snapshot on timeout or invalid data. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    if (_initialized) WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }

  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<AppPropertyScope>();
  }
}

class AppPropertyScope extends InheritedNotifier<AppProperties> {
  AppPropertyScope({super.key, required super.child})
    : super(notifier: AppProperties.instance);
}

class AppCopy {
  static String text(String key, {Map<String, String> arguments = const {}}) =>
      AppProperties.instance.text(key, arguments: arguments);
}

/// Remote artwork shares the bundled image's layout and error recovery.
class PropertyImage extends StatelessWidget {
  const PropertyImage(
    this.propertyKey, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
  });
  final String propertyKey;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    AppProperties.watch(context);
    Widget fallback() => Image.asset(
      propertyDefaults[propertyKey]!,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
    );
    var value = AppCopy.text(propertyKey);
    if (value.startsWith('brand-asset:')) {
      value =
          '${AppStrings.apiBaseUrl}${AppStrings.apiPathPrefix}/app-properties/assets/${value.substring(12)}';
    }
    if (value == propertyDefaults[propertyKey]) return fallback();
    return Image.network(
      value,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      errorBuilder: (_, _, _) => fallback(),
    );
  }
}
