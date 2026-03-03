import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// 网络状态 Provider
/// 提供全局可监听的网络状态
class NetworkProvider extends ChangeNotifier {
  final NetworkService _networkService = NetworkService();

  // 当前网络状态
  bool _isOnline = true;

  // 是否正在同步
  bool _isSyncing = false;

  // 获取当前网络状态
  bool get isOnline => _isOnline;

  // 是否正在同步
  bool get isSyncing => _isSyncing;

  // 初始化标记
  bool _initialized = false;

  /// 初始化网络状态监听
  Future<void> init() async {
    if (_initialized) return;

    // 初始化网络服务
    await _networkService.init();

    // 获取初始状态
    _isOnline = _networkService.isConnected;

    // 启动轮询监听
    _networkService.startPolling(
      onNetworkChanged: _onNetworkChanged,
    );

    _initialized = true;
    notifyListeners();

    debugPrint('[NetworkProvider] 初始化完成，当前状态: ${_isOnline ? "在线" : "离线"}');
  }

  /// 网络状态变化回调
  void _onNetworkChanged() {
    final newStatus = _networkService.isConnected;
    if (newStatus != _isOnline) {
      _isOnline = newStatus;
      notifyListeners();
      debugPrint('[NetworkProvider] 网络状态变化: ${_isOnline ? "在线" : "离线"}');
    }
  }

  /// 手动检查网络状态
  Future<void> checkNetwork() async {
    final newStatus = await _networkService.checkConnectivity();
    if (newStatus != _isOnline) {
      _isOnline = newStatus;
      notifyListeners();
    }
  }

  /// 设置同步状态
  void setSyncing(bool syncing) {
    if (_isSyncing != syncing) {
      _isSyncing = syncing;
      notifyListeners();
    }
  }

  /// 刷新网络状态
  Future<void> refresh() async {
    await checkNetwork();
  }

  @override
  void dispose() {
    _networkService.stopPolling();
    super.dispose();
  }
}
