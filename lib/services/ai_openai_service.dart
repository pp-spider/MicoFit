import 'dart:async';
import 'package:dart_openai/dart_openai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/ai_chat_context.dart';
import '../models/tool_schemas.dart';
import '../config/app_config.dart';

/// AI 服务异常
class AIServiceException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  AIServiceException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

/// OpenAI 服务封装
class AIOpenAIService {
  String? _baseUrl;
  String? _apiKey;
  String? _model;

  static const int _maxHistoryMessages = 10;

  /// 初始化配置
  Future<bool> _initConfig() async {
    if (_baseUrl != null && _apiKey != null && _model != null) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('ai_base_url')?.trim();
    _apiKey = prefs.getString('ai_api_key')?.trim();
    _model = prefs.getString('ai_model')?.trim();

    final hasConfig = _baseUrl != null &&
        _baseUrl!.isNotEmpty &&
        _apiKey != null &&
        _apiKey!.isNotEmpty &&
        _model != null &&
        _model!.isNotEmpty;

    if (hasConfig) {
      OpenAI.baseUrl = _baseUrl!;
      OpenAI.apiKey = _apiKey!;
    }

    return hasConfig;
  }

  /// ========== 流式响应方法 ==========

  /// 发送消息并获取流式响应
  /// 返回 Stream<String>，每次 emit 一个内容片段
  Stream<String> sendMessageStream({
    required String userMessage,
    required AIChatContext context,
  }) async* {
    final hasConfig = await _initConfig();
    if (!hasConfig) {
      throw AIServiceException('AI配置不完整，请检查配置', statusCode: 0);
    }

    try {
      final messages = _buildMessages(userMessage, context);

      // 创建流式请求
      final stream = OpenAI.instance.chat.createStream(
        model: _model!,
        messages: messages,
        temperature: AppConfig.defaultTemperature,
        maxTokens: AppConfig.maxTokens,
      );

      // 监听流式响应，直接 yield 增量内容
      await for (final chunk in stream) {
        final delta = chunk.choices.first.delta;
        // delta.content 可能为 null 或包含内容
        if (delta.content != null && delta.content!.isNotEmpty) {
          // 提取文本内容
          for (final item in delta.content!) {
            // 直接获取 text 属性（使用空检查）
            final text = item?.text;
            if (text != null && text.isNotEmpty) {
              yield text;  // 直接 yield 增量内容
            }
          }
        }
      }
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException(
        'API调用失败：${_parseError(e)}',
        originalError: e,
      );
    }
  }

  /// 发送消息并获取流式响应（支持工具调用）
  /// 返回 Stream<StreamResponseChunk>，包含文本内容和工具调用信息
  Stream<StreamResponseChunk> sendMessageStreamWithTools({
    required String userMessage,
    required AIChatContext context,
    List<Map<String, dynamic>>? additionalMessages,
  }) async* {
    final hasConfig = await _initConfig();
    if (!hasConfig) {
      throw AIServiceException('AI配置不完整，请检查配置', statusCode: 0);
    }

    try {
      // 构建消息列表
      final messages = <OpenAIChatCompletionChoiceMessageModel>[];

      // 添加系统提示词
      messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.system,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(
            context.toSystemPrompt(),
          ),
        ],
      ));

      // 添加历史消息
      final recentHistory = context.recentHistory.take(_maxHistoryMessages).toList();
      for (final msg in recentHistory) {
        messages.add(OpenAIChatCompletionChoiceMessageModel(
          role: msg.type == ChatMessageType.user
              ? OpenAIChatMessageRole.user
              : OpenAIChatMessageRole.assistant,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(msg.content),
          ],
        ));
      }

      // 添加当前用户消息
      messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: OpenAIChatMessageRole.user,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(userMessage),
        ],
      ));

      // 添加额外的消息（包含 tool_calls 的 assistant 消息或 tool 响应消息）
      if (additionalMessages != null) {
        for (final msgMap in additionalMessages) {
          final role = msgMap['role'] as String?;

          if (role == 'assistant' && msgMap.containsKey('tool_calls')) {
            // 处理包含 tool_calls 的 assistant 消息
            final toolCallsMaps = msgMap['tool_calls'] as List;
            final toolCalls = toolCallsMaps.map((tcMap) {
              return OpenAIResponseToolCall.fromMap(tcMap as Map<String, dynamic>);
            }).toList();

            messages.add(OpenAIChatCompletionChoiceMessageModel(
              role: OpenAIChatMessageRole.assistant,
              content: null,  // 无文本内容
              toolCalls: toolCalls,
            ));
          } else {
            // 处理工具响应消息
            final toolMsg = _ToolResponseMessage.fromMap(msgMap);
            messages.add(toolMsg);
          }
        }
      }

      // 用于收集每个工具调用的增量数据
      final Map<int, _ToolCallBuffer> toolCallBuffers = {};
      bool hasToolCalls = false;

      // 创建流式请求，传递工具定义
      final stream = OpenAI.instance.chat.createStream(
        model: _model!,
        messages: messages,
        tools: [AIToolSchemas.getUserProfileTool],
        temperature: AppConfig.defaultTemperature,
        maxTokens: AppConfig.maxTokens,
      );

      // 监听流式响应
      await for (final chunk in stream) {
        final delta = chunk.choices.first.delta;
        // 检测工具调用
        if (delta.haveToolCalls && delta.toolCalls != null) {
          hasToolCalls = true;
          for (final toolCall in delta.toolCalls!) {
            if (toolCall is OpenAIStreamResponseToolCall) {
              _collectToolCall(toolCallBuffers, toolCall);
            }
          }
        }

        // 提取文本内容
        if (delta.haveContent && delta.content != null) {
          for (final item in delta.content!) {
            final text = item?.text;
            if (text != null && text.isNotEmpty) {
              yield StreamResponseChunk(textContent: text);
            }
          }
        }
      }

      // 流结束后，如果检测到工具调用，返回工具调用信息
      if (hasToolCalls && toolCallBuffers.isNotEmpty) {
        // 将收集的工具调用信息转换为简化的Map格式供ChatProvider使用
        final toolCallMaps = <Map<String, dynamic>>[];
        for (final buffer in toolCallBuffers.values) {
          toolCallMaps.add({
            'id': buffer.id,
            'type': buffer.type,
            'function': {
              'name': buffer.name,
              'arguments': buffer.arguments,
            },
          });
        }
        // 返回包含工具调用的chunk
        yield StreamResponseChunk(toolCallData: toolCallMaps);
      }
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException(
        'API调用失败：${_parseError(e)}',
        originalError: e,
      );
    }
  }

  /// 收集工具调用的增量数据
  void _collectToolCall(
    Map<int, _ToolCallBuffer> buffers,
    OpenAIStreamResponseToolCall delta,
  ) {
    final index = delta.index;
    if (!buffers.containsKey(index)) {
      // 新的工具调用
      buffers[index] = _ToolCallBuffer(
        id: delta.id,
        type: delta.type,
        name: delta.function.name ?? '',
        arguments: delta.function.arguments ?? '',
      );
    } else {
      // 增量更新
      final buffer = buffers[index]!;
      if (delta.function.name != null && delta.function.name!.isNotEmpty) {
        buffer.name = delta.function.name!;
      }
      if (delta.function.arguments != null) {
        buffer.arguments += delta.function.arguments!;
      }
    }
  }

  /// ========== 非流式响应方法（用于降级） ==========

  /// 发送消息并获取完整回复（用于降级或不需要流式的场景）
  Future<String> sendMessage({
    required String userMessage,
    required AIChatContext context,
  }) async {
    final hasConfig = await _initConfig();
    if (!hasConfig) {
      throw AIServiceException('AI配置不完整，请检查配置', statusCode: 0);
    }

    try {
      final messages = _buildMessages(userMessage, context);

      final chatCompletion = await OpenAI.instance.chat.create(
        model: _model!,
        messages: messages,
        temperature: AppConfig.defaultTemperature,
        maxTokens: AppConfig.maxTokens,
      );

      // 提取响应内容
      final message = chatCompletion.choices.first.message;
      final contentItems = message.content;

      if (contentItems == null || contentItems.isEmpty) {
        throw AIServiceException('AI返回了空响应', statusCode: 200);
      }

      // 从 contentItems 中提取文本
      final buffer = StringBuffer();
      for (final item in contentItems) {
        final text = item.text;
        if (text != null && text.isNotEmpty) {
          buffer.write(text);
        }
      }

      final response = buffer.toString();
      if (response.isEmpty) {
        throw AIServiceException('AI返回了空响应', statusCode: 200);
      }

      return response;
    } on AIServiceException {
      rethrow;
    } catch (e) {
      throw AIServiceException(
        'API调用失败：${_parseError(e)}',
        originalError: e,
      );
    }
  }

  /// 构建消息列表
  List<OpenAIChatCompletionChoiceMessageModel> _buildMessages(
    String userMessage,
    AIChatContext context,
  ) {
    final messages = <OpenAIChatCompletionChoiceMessageModel>[];

    // 系统提示词
    messages.add(OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.system,
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(
          context.toSystemPrompt(),
        ),
      ],
    ));

    // 历史消息（最近N条）
    final recentHistory = context.recentHistory.take(_maxHistoryMessages).toList();
    for (final msg in recentHistory) {
      messages.add(OpenAIChatCompletionChoiceMessageModel(
        role: msg.type == ChatMessageType.user
            ? OpenAIChatMessageRole.user
            : OpenAIChatMessageRole.assistant,
        content: [
          OpenAIChatCompletionChoiceMessageContentItemModel.text(msg.content),
        ],
      ));
    }

    // 当前用户消息
    messages.add(OpenAIChatCompletionChoiceMessageModel(
      role: OpenAIChatMessageRole.user,
      content: [
        OpenAIChatCompletionChoiceMessageContentItemModel.text(userMessage),
      ],
    ));

    return messages;
  }

  /// 解析错误信息
  String _parseError(dynamic error) {
    final errorStr = error.toString();
    if (errorStr.contains('timeout')) return '请求超时';
    if (errorStr.contains('401') || errorStr.contains('Unauthorized')) {
      return 'API密钥无效';
    }
    if (errorStr.contains('429')) return '请求过于频繁';
    if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return '服务暂时不可用';
    }
    return errorStr;
  }

  /// 清除配置缓存
  void clearConfig() {
    _baseUrl = null;
    _apiKey = null;
    _model = null;
  }
}

/// 工具调用缓冲区（用于合并流式增量数据）
class _ToolCallBuffer {
  final String id;
  final String type;
  String name;
  String arguments;

  _ToolCallBuffer({
    String? id,
    String? type,
    required this.name,
    required this.arguments,
  })  : id = id ?? '',
        type = type ?? 'function';
}

/// 工具响应消息包装类
/// 继承 RequestFunctionMessage 并重写 toMap() 以使用正确的序列化格式
///
/// dart_openai 6.1.1+ 中 RequestFunctionMessage.toMap() 仍然使用数组格式
/// 我们重写该方法以使用父类的单元素优化逻辑
base class _ToolResponseMessage extends RequestFunctionMessage {
  _ToolResponseMessage({
    required String toolCallId,
    required String contentText,
  }) : super(
         role: OpenAIChatMessageRole.tool,
         toolCallId: toolCallId,
         content: [
           OpenAIChatCompletionChoiceMessageContentItemModel.text(contentText),
         ],
       );

  /// 从 Map 创建
  factory _ToolResponseMessage.fromMap(Map<String, dynamic> map) {
    return _ToolResponseMessage(
      toolCallId: map['tool_call_id'] as String? ?? '',
      contentText: map['content'] as String? ?? '',
    );
  }

  /// 重写 toMap() 以使用正确的序列化格式
  /// 当 content 只有 1 个元素时，直接返回字符串（而不是数组）
  @override
  Map<String, dynamic> toMap() {
    // 使用父类 OpenAIChatCompletionChoiceMessageModel 的优化逻辑
    final content_ = content?.length == 1
        ? content!.first.toMap(single: true)  // 返回字符串
        : content?.map((item) => item.toMap()).toList();

    return {
      "role": role.name,
      "content": content_,  // 单元素时是字符串，多元素时是数组
      "tool_call_id": toolCallId,
    };
  }
}
