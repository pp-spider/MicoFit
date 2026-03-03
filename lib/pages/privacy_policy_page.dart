import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 隐私政策页面
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('隐私政策'),
        backgroundColor: const Color(0xFFF5F5F0),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF115E59)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF115E59),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Markdown(
        data: _privacyContent,
        styleSheet: MarkdownStyleSheet(
          h1: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
            height: 1.5,
          ),
          h2: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF115E59),
            height: 1.5,
          ),
          p: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.6,
          ),
          listBullet: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        padding: const EdgeInsets.all(16),
      ),
    );
  }
}

const String _privacyContent = '''
# 微动 MicoFit 隐私政策

**最后更新日期：2026年2月**

## 1. 引言

微动 MicoFit（以下简称"我们"）非常重视用户的隐私保护。本隐私政策说明了我们如何收集、使用、存储和保护您的个人信息。

## 2. 信息收集

### 2.1 您主动提供的信息
- 账户信息：邮箱、密码
- 个人资料：昵称、性别、年龄、身高、体重
- 健身信息：健身目标、健身水平、可用场景、时间安排
- 训练反馈：完成度、身体感受、疼痛部位

### 2.2 自动收集的信息
- 设备信息：设备型号、操作系统版本、设备标识符
- 日志信息：IP地址、访问时间、使用时长、操作记录
- 训练数据：训练计划、完成状态、训练时长、打卡记录

### 2.3 AI 服务相关
- 聊天记录：与 AI 教练的对话内容
- 使用 AI 功能时的上下文信息

## 3. 信息使用

我们使用收集的信息用于：
- 提供、维护和改进本应用服务
- 生成个性化的训练计划
- 记录和统计您的训练数据
- 与您沟通，包括发送服务通知
- 改进 AI 服务质量
- 保障账户安全

## 4. 信息存储与保护

### 4.1 存储位置
- 您的数据存储在安全的服务器上
- 部分数据可能在本地设备上缓存以支持离线使用

### 4.2 安全措施
- 使用加密技术保护数据传输
- 实施访问控制和身份验证
- 定期进行安全评估

### 4.3 数据保留
- 账户信息：保留至您删除账户
- 训练数据：保留至您删除账户
- 聊天记录：保留 90 天后自动删除

## 5. 信息共享

我们不会向第三方出售您的个人信息。仅在以下情况下可能共享：
- 获得您的明确同意
- 法律法规要求
- 保护我们的合法权益
- 服务提供商（仅在必要的范围内）

## 6. 您的权利

您对自己的个人信息拥有以下权利：
- **访问权**：查看您的个人信息
- **更正权**：修改不准确的信息
- **删除权**：请求删除您的账户和数据
- **导出权**：导出您的训练数据
- **撤回同意**：撤回对信息处理的同意

## 7. Cookie 和类似技术

我们可能使用 Cookie 和类似技术来改善用户体验，包括：
- 保持登录状态
- 记住您的偏好设置
- 分析应用使用情况

## 8. 未成年人保护

- 本应用不面向 14 岁以下未成年人
- 如我们发现收集了未成年人的信息，将立即删除

## 9. 隐私政策更新

我们可能不时更新本隐私政策。更新后的政策将在应用中公布，重大变更将通知您。

## 10. 联系我们

如有任何隐私相关问题，请联系我们：
- 邮箱：privacy@micofit.com

## 11. 其他

### 11.1 第三方服务
本应用可能包含第三方服务的链接，这些服务有各自的隐私政策。

### 11.2 国际数据传输
您的数据可能在中国境内存储和处理。

---

感谢您信任微动 MicoFit。我们承诺保护您的隐私，让您安心享受运动乐趣。
''';