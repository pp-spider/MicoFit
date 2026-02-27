import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../models/weekly_data.dart';
import 'ai_api_service.dart';

/// 熔断器状态
enum CircuitBreakerState {
  closed,    // 正常状态，请求可以通过
  open,      // 熔断状态，请求被拒绝
  halfOpen,  // 半开状态，测试请求是否恢复
}

/// 熔断器
/// 防止 AI 服务故障时持续发送请求
class CircuitBreaker {
  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;

  final int failureThreshold;
  final Duration timeoutDuration;
  final Duration halfOpenTimeout;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeoutDuration = const Duration(seconds: 30),
    this.halfOpenTimeout = const Duration(seconds: 10),
  });

  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;

  /// 记录成功
  void recordSuccess() {
    _failureCount = 0;
    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.closed;
    }
  }

  /// 记录失败
  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();

    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.open;
    } else if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
    }
  }

  /// 检查是否允许请求
  bool canExecute() {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        // 检查是否超时，可以进入半开状态
        if (_lastFailureTime != null) {
          final elapsed = DateTime.now().difference(_lastFailureTime!);
          if (elapsed > timeoutDuration) {
            _state = CircuitBreakerState.halfOpen;
            return true;
          }
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// 重置熔断器
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
  }
}

/// AI 缓存条目
class _CacheEntry {
  final String key;
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry({
    required this.key,
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// AI 响应缓存
class AIResponseCache {
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();
  final int maxSize;
  final Duration defaultTtl;

  AIResponseCache({
    this.maxSize = 100,
    this.defaultTtl = const Duration(minutes: 5),
  });

  /// 获取缓存
  dynamic get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    // 移动到末尾（LRU）
    _cache.remove(key);
    _cache[key] = entry;
    return entry.data;
  }

  /// 设置缓存
  void set(String key, dynamic data, {Duration? ttl}) {
    // 移除最旧的条目如果超过容量
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CacheEntry(
      key: key,
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? defaultTtl,
    );
  }

  /// 清除缓存
  void clear() => _cache.clear();

  /// 移除特定键
  void remove(String key) => _cache.remove(key);
}

/// 上下文压缩器
/// 优化长对话的 token 使用
class ContextCompressor {
  final int maxContextLength;
  final int maxMessages;

  ContextCompressor({
    this.maxContextLength = 4000,
    this.maxMessages = 20,
  });

  /// 压缩消息列表
  List<Map<String, dynamic>> compress(List<Map<String, dynamic>> messages) {
    if (messages.length <= maxMessages) {
      return messages;
    }

    // 保留第一条（系统提示）和最后 N-1 条
    final compressed = <Map<String, dynamic>>[
      messages.first,
      ...messages.sublist(messages.length - maxMessages + 1),
    ];

    return compressed;
  }

  /// 压缩长文本
  String compressText(String text, {int maxLength = 1000}) {
    if (text.length <= maxLength) return text;

    // 提取关键信息
    final lines = text.split('\n');
    if (lines.length > 20) {
      // 保留前10行和后10行
      return '${lines.take(10).join('\n')}\n...\n${lines.skip(lines.length - 10).join('\n')}';
    }

    return '${text.substring(0, maxLength)}...';
  }

  /// 总结历史对话
  String summarizeHistory(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '';

    final userMessages = messages
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] as String?)
        .where((c) => c != null)
        .toList();

    if (userMessages.isEmpty) return '';

    // 提取关键主题
    final topics = <String>{};
    for (final msg in userMessages.take(5)) {
      if (msg!.contains('训练')) topics.add('训练计划');
      if (msg.contains('减脂')) topics.add('减脂');
      if (msg.contains('增肌')) topics.add('增肌');
      if (msg.contains('拉伸')) topics.add('拉伸');
      if (msg.contains('饮食')) topics.add('饮食');
    }

    if (topics.isEmpty) return '';

    return '历史讨论主题: ${topics.join(', ')}';
  }
}

/// 重试配置
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 10),
    this.backoffMultiplier = 2.0,
  });
}

/// 增强型 AI 服务
/// 包含重试机制、熔断器、缓存和上下文压缩
class AIEnhancedService {
  final AIApiService _apiService;
  final CircuitBreaker _circuitBreaker;
  final AIResponseCache _cache;
  final ContextCompressor _compressor;
  final RetryConfig _retryConfig;

  AIEnhancedService({
    AIApiService? apiService,
    CircuitBreaker? circuitBreaker,
    AIResponseCache? cache,
    ContextCompressor? compressor,
    RetryConfig? retryConfig,
  })  : _apiService = apiService ?? AIApiService(),
        _circuitBreaker = circuitBreaker ?? CircuitBreaker(),
        _cache = cache ?? AIResponseCache(),
        _compressor = compressor ?? ContextCompressor(),
        _retryConfig = retryConfig ?? const RetryConfig();

  /// 带重试的流式聊天
  Stream<AIStreamChunk> sendMessageStreamWithRetry({
    String? sessionId,
    required String message,
    List<Map<String, dynamic>>? contextMessages,
  }) async* {
    // 检查熔断器
    if (!_circuitBreaker.canExecute()) {
      yield AIStreamChunk(
        type: AIStreamType.error,
        message: 'AI 服务暂时不可用，请稍后重试',
      );
      return;
    }

    // 压缩上下文
    if (contextMessages != null && contextMessages.length > 20) {
      contextMessages = _compressor.compress(contextMessages);
    }

    var attempt = 0;
    var delay = _retryConfig.initialDelay;

    while (attempt < _retryConfig.maxAttempts) {
      try {
        await for (final chunk in _apiService.sendMessageStream(
          sessionId: sessionId,
          message: message,
        )) {
          _circuitBreaker.recordSuccess();
          yield chunk;
        }
        return;
      } catch (e) {
        attempt++;
        _circuitBreaker.recordFailure();

        if (attempt >= _retryConfig.maxAttempts) {
          yield AIStreamChunk(
            type: AIStreamType.error,
            message: '请求失败，已重试 $_retryConfig.maxAttempts 次: $e',
          );
          return;
        }

        debugPrint('AI 请求失败 (尝试 $attempt/$_retryConfig.maxAttempts): $e');

        // 等待后重试
        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (
            delay.inMilliseconds * _retryConfig.backoffMultiplier
          ).clamp(0, _retryConfig.maxDelay.inMilliseconds).toInt(),
        );
      }
    }
  }

  /// 带缓存的训练计划生成
  Stream<AIStreamChunk> generateWorkoutPlanWithCache({
    Map<String, dynamic>? preferences,
  }) async* {
    // 生成缓存键
    final cacheKey = _generateCacheKey('plan', preferences);

    // 检查缓存
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      debugPrint('使用缓存的训练计划');
      yield AIStreamChunk(
        type: AIStreamType.chunk,
        content: '（来自缓存）\n\n$cached',
      );
      yield AIStreamChunk(type: AIStreamType.done);
      return;
    }

    // 检查熔断器
    if (!_circuitBreaker.canExecute()) {
      yield AIStreamChunk(
        type: AIStreamType.error,
        message: 'AI 服务暂时不可用，请稍后重试',
      );
      return;
    }

    var attempt = 0;
    var delay = _retryConfig.initialDelay;
    final buffer = StringBuffer();

    while (attempt < _retryConfig.maxAttempts) {
      try {
        await for (final chunk in _apiService.generateWorkoutPlanStream(
          preferences: preferences,
        )) {
          _circuitBreaker.recordSuccess();

          // 缓存文本内容
          if (chunk.type == AIStreamType.chunk && chunk.content != null) {
            buffer.write(chunk.content);
          }

          yield chunk;

          if (chunk.type == AIStreamType.done) {
            // 保存到缓存
            if (buffer.isNotEmpty) {
              _cache.set(
                cacheKey,
                buffer.toString(),
                ttl: const Duration(minutes: 10),
              );
            }
            return;
          }
        }
        return;
      } catch (e) {
        attempt++;
        _circuitBreaker.recordFailure();

        if (attempt >= _retryConfig.maxAttempts) {
          yield AIStreamChunk(
            type: AIStreamType.error,
            message: '生成计划失败，已重试 $attempt 次: $e',
          );
          return;
        }

        debugPrint('生成计划失败 (尝试 $attempt/$_retryConfig.maxAttempts): $e');

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (
            delay.inMilliseconds * _retryConfig.backoffMultiplier
          ).clamp(0, _retryConfig.maxDelay.inMilliseconds).toInt(),
        );
      }
    }
  }

  /// 生成 AI 智能训练报告
  Future<String> generateSmartTrainingReport({
    required MonthlyStats monthlyStats,
    required List<WorkoutPlan> recentWorkouts,
    required Map<String, int> sceneDistribution,
  }) async {
    // 检查熔断器
    if (!_circuitBreaker.canExecute()) {
      return 'AI 服务暂时不可用，无法生成智能报告。\n\n您可以查看基础统计数据了解本月训练情况。';
    }

    // 检查缓存
    final cacheKey = 'report_${monthlyStats.year}_${monthlyStats.month}';
    final cached = _cache.get(cacheKey);
    if (cached != null) {
      return cached as String;
    }

    try {
      // 构建提示
      final prompt = _buildReportPrompt(
        monthlyStats: monthlyStats,
        recentWorkouts: recentWorkouts,
        sceneDistribution: sceneDistribution,
      );

      // 调用 AI
      final response = await _apiService.generateWorkoutPlan(
        preferences: {'prompt': prompt, 'type': 'training_report'},
      );

      final report = response['content'] as String? ??
        _generateFallbackReport(monthlyStats);

      // 缓存报告
      _cache.set(cacheKey, report, ttl: const Duration(hours: 1));

      _circuitBreaker.recordSuccess();
      return report;
    } catch (e) {
      _circuitBreaker.recordFailure();
      debugPrint('生成智能训练报告失败: $e');
      return _generateFallbackReport(monthlyStats);
    }
  }

  /// 构建报告提示
  String _buildReportPrompt({
    required MonthlyStats monthlyStats,
    required List<WorkoutPlan> recentWorkouts,
    required Map<String, int> sceneDistribution,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('请根据以下训练数据生成一份个性化的月度训练报告：');
    buffer.writeln();
    buffer.writeln('## 基础数据');
    buffer.writeln('- 本月完成训练：${monthlyStats.completedDays} 天');
    buffer.writeln('- 总训练时长：${monthlyStats.totalMinutes} 分钟');
    buffer.writeln('- 目标完成率：${monthlyStats.progressPercent.toStringAsFixed(1)}%');
    buffer.writeln('- 日均训练：${monthlyStats.avgDailyMinutes.toStringAsFixed(1)} 分钟');
    buffer.writeln();

    if (sceneDistribution.isNotEmpty) {
      buffer.writeln('## 场景分布');
      sceneDistribution.forEach((scene, count) {
        buffer.writeln('- $scene: $count 次');
      });
      buffer.writeln();
    }

    if (recentWorkouts.isNotEmpty) {
      buffer.writeln('## 最近训练');
      for (final workout in recentWorkouts.take(5)) {
        buffer.writeln('- ${workout.title} (${workout.totalDuration}分钟)');
      }
      buffer.writeln();
    }

    buffer.writeln('## 要求');
    buffer.writeln('1. 总结本月训练成果');
    buffer.writeln('2. 分析训练习惯和偏好');
    buffer.writeln('3. 给出下月训练建议');
    buffer.writeln('4. 使用鼓励性的语气');
    buffer.writeln('5. 控制在300字以内');

    return buffer.toString();
  }

  /// 生成备用报告（AI 不可用时）
  String _generateFallbackReport(MonthlyStats stats) {
    final buffer = StringBuffer();

    buffer.writeln('## 📊 本月训练总结');
    buffer.writeln();
    buffer.writeln('本月你完成了 **${stats.completedDays}** 天训练，');
    buffer.writeln('总时长达到 **${stats.totalMinutes}** 分钟，');
    buffer.writeln('目标完成率为 **${stats.progressPercent.toStringAsFixed(1)}%**。');
    buffer.writeln();

    if (stats.progressPercent >= 80) {
      buffer.writeln('🎉 太棒了！你的训练目标完成度很高，');
      buffer.writeln('保持了良好的运动习惯。');
    } else if (stats.progressPercent >= 50) {
      buffer.writeln('💪 不错的开始！继续坚持下去，');
      buffer.writeln('下月争取达到更高目标。');
    } else {
      buffer.writeln('🌱 运动习惯正在养成中，');
      buffer.writeln('建议逐步增加训练频率。');
    }
    buffer.writeln();

    buffer.writeln('## 🎯 下月建议');
    buffer.writeln('- 保持当前训练节奏');
    buffer.writeln('- 尝试不同场景的训练');
    buffer.writeln('- 注意休息和恢复');

    return buffer.toString();
  }

  /// 重置熔断器
  void resetCircuitBreaker() {
    _circuitBreaker.reset();
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  /// 获取服务状态
  Map<String, dynamic> getServiceStatus() {
    return {
      'circuit_breaker_state': _circuitBreaker.state.name,
      'circuit_breaker_failures': _circuitBreaker.failureCount,
      'cache_size': _cache.toString(),
    };
  }

  /// 生成缓存键
  String _generateCacheKey(String prefix, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) {
      return prefix;
    }

    final sortedParams = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final paramString = sortedParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    return '${prefix}_$paramString';
  }
}
