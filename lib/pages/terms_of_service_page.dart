import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 用户协议页面
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        title: const Text('用户协议'),
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
        data: _termsContent,
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

const String _termsContent = '''
# 微动 MicoFit 用户协议

**最后更新日期：2026年2月**

## 1. 协议概述

欢迎使用微动 MicoFit（以下简称"本应用"）。本协议是您（用户）与微动之间关于使用本应用服务的协议。通过使用本应用，您表示同意接受本协议的所有条款和条件。

## 2. 服务内容

本应用是一款基于人工智能的健身指导应用，为用户提供：
- 个性化的每日训练计划生成
- 健身动作指导和计时
- 训练数据记录和统计
- AI 健身咨询服务

## 3. 用户责任

### 3.1 账户安全
- 您应对自己的账户和密码安全负责
- 不得将账户转让、出借或分享给他人使用
- 发现账户异常应立即通知我们

### 3.2 使用规范
- 不得利用本应用从事违法违规活动
- 不得干扰或破坏本应用的正常运行
- 不得侵犯他人的知识产权或其他合法权益

### 3.3 健康声明
- 使用本应用前，请确认您的身体状况适合进行运动
- 如有心脏病、高血压等疾病，请在医生指导下运动
- 运动过程中如感到不适，请立即停止并咨询医生
- 本应用提供的建议仅供参考，不构成医疗建议

## 4. 知识产权

- 本应用的所有内容（包括但不限于文字、图片、音频、视频、软件等）均受知识产权保护
- 未经授权，不得复制、修改、传播本应用的任何内容
- 用户上传的内容，用户保留知识产权，但授予我们使用许可

## 5. 免责声明

- 本应用按"现状"提供，不保证服务的连续性、及时性、安全性
- 因不可抗力导致的服务中断，我们不承担责任
- 因用户自身原因造成的损失，我们不承担责任
- 运动伤害风险由用户自行承担

## 6. 协议修改

我们有权随时修改本协议。修改后的协议将在本应用中公布，继续使用视为接受修改。

## 7. 终止服务

如您违反本协议，我们有权终止向您提供服务，并保留追究法律责任的权利。

## 8. 适用法律

本协议适用中华人民共和国法律。如有争议，双方应友好协商解决；协商不成的，提交我们有管辖权的法院解决。

## 9. 联系我们

如有任何问题，请联系我们：
- 邮箱：support@micofit.com

感谢您选择微动 MicoFit，祝您运动愉快！
''';