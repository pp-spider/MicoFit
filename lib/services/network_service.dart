import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络状态服务
/// 监听网络连接状态变化，提供当前网络状态查询
class NetworkService {
  // 单例模式
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  // Connectivity 实例
  final Connectivity _connectivity = Connectivity();

  // 网络状态流控制器（返回列表）
  final StreamController<List<ConnectivityResult>> _connectionStatusController =
      StreamController<List<ConnectivityResult>>.broadcast();

  // 当前连接状态缓存（列表）
  List<ConnectivityResult> _cachedResult = [];

  // 初始化状态
  bool _initialized = false;

  /// 获取网络状态流
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectionStatusController.stream;

  /// 初始化网络状态监听
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时获取当前状态
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('[NetworkService] 初始化获取网络状态失败: $e');
    }

    // 监听网络状态变化
    _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });

    _initialized = true;
    debugPrint('[NetworkService] 网络状态监听已初始化');
  }

  /// 更新连接状态
  void _updateConnectionStatus(List<ConnectivityResult> result) {
    _cachedResult = result;
    _connectionStatusController.add(result);
    _logConnectionChange(result);
  }

  /// 获取当前是否在线
  Future<bool> get isConnected async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[NetworkService] 检查网络状态失败: $e');
      // 出错时假设有连接
      return true;
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

  /// 获取缓存的连接状态（同步获取，不需要等待）
  List<ConnectivityResult> get cachedConnectionStatus =>
      List.unmodifiable(_cachedResult);

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

  /// 记录网络状态变化
  void _logConnectionChange(List<ConnectivityResult> results) {
    final label = getConnectionLabel(results);
    final isConnected = hasConnection(results);
    debugPrint(
        '[NetworkService] 网络状态变化: $label (${isConnected ? "在线" : "离线"})');
  }

  /// 释放资源
  void dispose() {
    _connectionStatusController.close();
    _initialized = false;
  }
}
