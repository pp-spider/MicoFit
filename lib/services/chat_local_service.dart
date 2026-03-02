import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../models/workout.dart';
import '../utils/user_data_helper.dart';

/// 聊天记录本地服务 - 用户数据隔离
class ChatLocalService {
  // 存储key
  static const String _chatHistoryKey = 'chat_history';
  static const String _pendingPlanKey = 'pending_workout_plan';
  static const String _respondedPlanKey = 'responded_workout_plan';
  static const String _isPlanConfirmedKey = 'is_plan_confirmed';

  // 最大保存消息数量
  static const int _maxMessages = 100;

  /// 加载聊天历史
  Future<List<ChatMessage>> loadChatHistory() async {
    final historyJson = await UserDataHelper.getString(_chatHistoryKey);

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
    await UserDataHelper.setString(_chatHistoryKey, historyJson);
  }

  /// 清空聊天历史
  Future<void> clearChatHistory() async {
    await UserDataHelper.remove(_chatHistoryKey);
  }

  /// 删除单条消息（按ID）
  Future<void> deleteMessage(String messageId) async {
    List<ChatMessage> history = await loadChatHistory();
    history.removeWhere((msg) => msg.id == messageId);

    final historyJson = jsonEncode(
      history.map((msg) => msg.toJson()).toList(),
    );
    await UserDataHelper.setString(_chatHistoryKey, historyJson);
  }

  /// 保存待确认的健身计划
  Future<void> savePendingPlan(WorkoutPlan plan) async {
    await UserDataHelper.setString(_pendingPlanKey, jsonEncode(plan.toJson()));
  }

  /// 加载待确认的健身计划
  Future<WorkoutPlan?> loadPendingPlan() async {
    final planJson = await UserDataHelper.getString(_pendingPlanKey);
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
    await UserDataHelper.remove(_pendingPlanKey);
  }

  /// 保存已响应的健身计划（确认或取消）
  Future<void> saveRespondedPlan(WorkoutPlan plan, bool isConfirmed) async {
    await UserDataHelper.setString(_respondedPlanKey, jsonEncode(plan.toJson()));
    await UserDataHelper.setBool(_isPlanConfirmedKey, isConfirmed);
  }

  /// 加载已响应的健身计划
  Future<WorkoutPlan?> loadRespondedPlan() async {
    final planJson = await UserDataHelper.getString(_respondedPlanKey);
    if (planJson == null) return null;

    try {
      final json = jsonDecode(planJson) as Map<String, dynamic>;
      return WorkoutPlan.fromJson(json);
    } catch (e) {
      debugPrint('加载已响应计划失败: $e');
      return null;
    }
  }

  /// 加载计划响应状态
  Future<bool?> loadIsPlanConfirmed() async {
    return await UserDataHelper.getBool(_isPlanConfirmedKey);
  }

  /// 清除已响应的健身计划
  Future<void> clearRespondedPlan() async {
    await UserDataHelper.remove(_respondedPlanKey);
    await UserDataHelper.remove(_isPlanConfirmedKey);
  }

  // ========== 多计划支持（新增）==========

  static const String _pendingPlansKey = 'pending_workout_plans';
  static const String _respondedPlansKey = 'responded_workout_plans';
  static const String _planStatusesKey = 'plan_statuses';

  /// 保存待确认的健身计划列表
  Future<void> savePendingPlans(List<WorkoutPlan> plans) async {
    final plansJson = jsonEncode(plans.map((p) => p.toJson()).toList());
    await UserDataHelper.setString(_pendingPlansKey, plansJson);
  }

  /// 加载待确认的健身计划列表
  Future<List<WorkoutPlan>> loadPendingPlans() async {
    final plansJson = await UserDataHelper.getString(_pendingPlansKey);
    if (plansJson == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(plansJson);
      return jsonList
          .map((json) => WorkoutPlan.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('加载待确认计划列表失败: $e');
      return [];
    }
  }

  /// 清除待确认的健身计划列表
  Future<void> clearPendingPlans() async {
    await UserDataHelper.remove(_pendingPlansKey);
  }

  /// 保存计划响应状态（用于多计划场景）
  /// key: plan.id, value: {'responded': bool, 'confirmed': bool}
  Future<void> savePlanStatuses(Map<String, Map<String, dynamic>> statuses) async {
    await UserDataHelper.setString(_planStatusesKey, jsonEncode(statuses));
  }

  /// 加载计划响应状态
  Future<Map<String, Map<String, dynamic>>> loadPlanStatuses() async {
    final json = await UserDataHelper.getString(_planStatusesKey);
    if (json == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(json);
      return decoded.map((key, value) =>
        MapEntry(key, (value as Map<String, dynamic>)));
    } catch (e) {
      debugPrint('加载计划状态失败: $e');
      return {};
    }
  }

  /// 清除计划响应状态
  Future<void> clearPlanStatuses() async {
    await UserDataHelper.remove(_planStatusesKey);
  }

  /// 保存已响应的计划列表
  Future<void> saveRespondedPlans(
    List<WorkoutPlan> plans,
    Map<String, bool> confirmedMap,
  ) async {
    final plansJson = jsonEncode(plans.map((p) => p.toJson()).toList());
    await UserDataHelper.setString(_respondedPlansKey, plansJson);
    await UserDataHelper.setString(
      '${_respondedPlansKey}_status',
      jsonEncode(confirmedMap),
    );
  }

  /// 加载已响应的计划列表
  Future<List<WorkoutPlan>> loadRespondedPlans() async {
    final plansJson = await UserDataHelper.getString(_respondedPlansKey);
    if (plansJson == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(plansJson);
      return jsonList
          .map((json) => WorkoutPlan.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('加载已响应计划列表失败: $e');
      return [];
    }
  }

  /// 加载已响应计划的确认状态映射
  Future<Map<String, bool>> loadRespondedPlanStatuses() async {
    final json = await UserDataHelper.getString('${_respondedPlansKey}_status');
    if (json == null) return {};

    try {
      final Map<String, dynamic> decoded = jsonDecode(json);
      return decoded.map((key, value) => MapEntry(key, value as bool));
    } catch (e) {
      debugPrint('加载已响应计划状态失败: $e');
      return {};
    }
  }

  /// 清除已响应的计划列表
  Future<void> clearRespondedPlans() async {
    await UserDataHelper.remove(_respondedPlansKey);
    await UserDataHelper.remove('${_respondedPlansKey}_status');
  }
}
