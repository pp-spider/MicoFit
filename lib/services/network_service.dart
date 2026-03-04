import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络状态服务
/// 使用轮询机制检查网络连接状态
class NetworkService {
  // 单例模式
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  // Connectivity 实例
  final Connectivity _connectivity = Connectivity();

  // 当前连接状态缓存（列表）
  List<ConnectivityResult> _cachedResult = [];

  // 初始化状态
  bool _initialized = false;

  // 轮询间隔（毫秒）
  static const int _pollIntervalMs = 3000; // 3秒检查一次

  // 轮询定时器
  Timer? _pollTimer;

  // 轮询回调
  Function()? _onNetworkChangedCallback;

  // 上次网络状态（用于检测变化）
  bool _lastKnownConnected = false;

  /// 启动轮询检查网络状态
  void startPolling({Function()? onNetworkChanged}) {
    _onNetworkChangedCallback = onNetworkChanged;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _pollIntervalMs),
      (_) => _checkNetworkStatus(),
    );
    debugPrint('[NetworkService] 轮询已启动，间隔: ${_pollIntervalMs}ms');
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onNetworkChangedCallback = null;
    debugPrint('[NetworkService] 轮询已停止');
  }

  /// 内部检查网络状态
  Future<void> _checkNetworkStatus() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
      final networkType = getConnectionLabel(result);

      // 检测到网络状态变化
      if (isConnected != _lastKnownConnected) {
        _lastKnownConnected = isConnected;
        _cachedResult = result;

        // 触发回调
        if (_onNetworkChangedCallback != null) {
          _onNetworkChangedCallback!();
        }
      } 
    } catch (e) {
      debugPrint('[NetworkService] [轮询] 检查网络状态失败: $e');
    }
  }

  /// 初始化网络状态
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时获取当前状态
    try {
      final result = await _connectivity.checkConnectivity();
      _cachedResult = result;
      _lastKnownConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[NetworkService] 初始化获取网络状态失败: $e');
    }

    _initialized = true;
    debugPrint('[NetworkService] 网络状态服务已初始化');
  }

  /// 获取当前是否在线（同步获取缓存）
  bool get isConnected {
    return _cachedResult.isNotEmpty && !_cachedResult.contains(ConnectivityResult.none);
  }

  /// 获取当前是否在线（异步方法，兼容旧代码）
  Future<bool> isConnectedAsync() async {
    return checkConnectivity();
  }

  /// 获取缓存的连接状态（同步获取，不需要等待）
  List<ConnectivityResult> get cachedConnectionStatus =>
      List.unmodifiable(_cachedResult);

  /// 主动检查网络状态（异步）
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[NetworkService] 检查网络状态失败: $e');
      return true; // 出错时假设有连接
    }
  }

  /// 获取当前网络类型列表
  Future<List<ConnectivityResult>> get networkType async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (e) {
      debugPrint('[NetworkService] 获取网络类型失败: $e');
      return [ConnectivityResult.none];
    }
  }

  /// 判断是否有任何网络连接
  bool hasConnection(List<ConnectivityResult>? result) {
    if (result == null || result.isEmpty) return false;
    return !result.contains(ConnectivityResult.none);
  }

  /// 判断是否通过移动网络连接
  bool isMobileConnection(List<ConnectivityResult>? result) {
    if (result == null || result.isEmpty) return false;
    return result.contains(ConnectivityResult.mobile);
  }

  /// 判断是否通过WiFi连接
  bool isWifiConnection(List<ConnectivityResult>? result) {
    if (result == null || result.isEmpty) return false;
    return result.contains(ConnectivityResult.wifi);
  }

  /// 判断是否离线（无网络）
  bool isOffline(List<ConnectivityResult>? result) {
    if (result == null || result.isEmpty) return true;
    return result.contains(ConnectivityResult.none) && result.length == 1;
  }

  /// 获取网络类型的可读标签
  static String getConnectionLabel(List<ConnectivityResult> results) {
    if (results.isEmpty) return '未知';
    if (results.contains(ConnectivityResult.none)) return '离线';

    final labels = <String>[];
    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          labels.add('WiFi');
          break;
        case ConnectivityResult.mobile:
          labels.add('移动网络');
          break;
        case ConnectivityResult.ethernet:
          labels.add('有线网络');
          break;
        case ConnectivityResult.vpn:
          labels.add('VPN');
          break;
        default:
          break;
      }
    }

    return labels.isEmpty ? '未知' : labels.join(', ');
  }

  /// 获取网络类型的图标（取第一个非none的类型）
  static IconData getConnectionIcon(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return Icons.signal_wifi_off;
    }

    for (final result in results) {
      switch (result) {
        case ConnectivityResult.wifi:
          return Icons.wifi;
        case ConnectivityResult.mobile:
          return Icons.signal_cellular_alt;
        case ConnectivityResult.ethernet:
          return Icons.settings_ethernet;
        case ConnectivityResult.vpn:
          return Icons.vpn_lock;
        default:
          continue;
      }
    }

    return Icons.signal_wifi_off;
  }

  /// 释放资源
  void dispose() {
    stopPolling();
    _initialized = false;
  }
}
