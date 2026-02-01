import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/workout.dart';

/// 聊天记录本地服务
class ChatLocalService {
  // 存储key
  static const String _chatHistoryKey = 'chat_history';
  static const String _pendingPlanKey = 'pending_workout_plan';

  // 最大保存消息数量
  static const int _maxMessages = 100;

  /// 加载聊天历史
  Future<List<ChatMessage>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_chatHistoryKey);

    if (historyJson == null) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(historyJson);
      return jsonList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 解析失败，返回空列表
      return [];
    }
  }

  /// 保存聊天消息
  Future<void> saveMessage(ChatMessage message) async {
    final prefs = await SharedPreferences.getInstance();

    // 加载现有历史
    List<ChatMessage> history = await loadChatHistory();

    // 添加新消息
    history.add(message);

    // 限制消息数量（保留最新的N条）
    if (history.length > _maxMessages) {
      history = history.sublist(history.length - _maxMessages);
    }

    // 保存到本地
    final historyJson = jsonEncode(
      history.map((msg) => msg.toJson()).toList(),
    );
    await prefs.setString(_chatHistoryKey, historyJson);
  }

  /// 清空聊天历史
  Future<void> clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatHistoryKey);
  }

  /// 删除单条消息（按ID）
  Future<void> deleteMessage(String messageId) async {
    final prefs = await SharedPreferences.getInstance();

    List<ChatMessage> history = await loadChatHistory();
    history.removeWhere((msg) => msg.id == messageId);

    final historyJson = jsonEncode(
      history.map((msg) => msg.toJson()).toList(),
    );
    await prefs.setString(_chatHistoryKey, historyJson);
  }

  /// 保存待确认的健身计划
  Future<void> savePendingPlan(WorkoutPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingPlanKey, jsonEncode(plan.toJson()));
  }

  /// 加载待确认的健身计划
  Future<WorkoutPlan?> loadPendingPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final planJson = prefs.getString(_pendingPlanKey);
    if (planJson == null) return null;

    try {
      final json = jsonDecode(planJson) as Map<String, dynamic>;
      return WorkoutPlan.fromJson(json);
    } catch (e) {
      debugPrint('加载待确认计划失败: $e');
      return null;
    }
  }

  /// 清除待确认的健身计划
  Future<void> clearPendingPlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPlanKey);
  }
}
