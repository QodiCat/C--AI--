import "dart:async";

import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/network/auth_session.dart";
import "../data/auth_repository.dart";
import "password_page.dart";

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _code = TextEditingController();
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _sendingCode = false;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _repository =
      AuthRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  bool _registering = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = "请输入有效邮箱");
      return;
    }
    setState(() {
      _sendingCode = true;
      _error = null;
    });
    try {
      await _repository.sendRegistrationCode(email);
      if (!mounted) return;
      setState(() => _resendSeconds = 60);
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _resendSeconds--);
        if (_resendSeconds <= 0) timer.cancel();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("验证码已发送，10 分钟内有效，请查看邮箱")));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = "无法连接服务，请稍后重试");
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = _registering
          ? await _repository.register(_email.text.trim(), _password.text,
              _nickname.text.trim(), _code.text.trim())
          : await _repository.login(_email.text.trim(), _password.text);
      final data = response["data"] as Map<String, dynamic>;
      await AuthSession.save(data["accessToken"] as String);
      widget.onAuthenticated();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = "无法连接服务，请稍后重试");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Icon(Icons.checkroom, size: 52),
                            const SizedBox(height: 18),
                            Text("AI衣橱",
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 30),
                            if (_registering)
                              TextFormField(
                                  controller: _nickname,
                                  decoration: const InputDecoration(
                                      labelText: "昵称",
                                      prefixIcon: Icon(Icons.person_outline))),
                            if (_registering) const SizedBox(height: 14),
                            TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                    labelText: "邮箱",
                                    prefixIcon: Icon(Icons.mail_outline)),
                                validator: (value) =>
                                    value != null && value.contains("@")
                                        ? null
                                        : "请输入有效邮箱"),
                            const SizedBox(height: 14),
                            TextFormField(
                                controller: _password,
                                obscureText: true,
                                decoration: const InputDecoration(
                                    labelText: "密码",
                                    prefixIcon: Icon(Icons.lock_outline)),
                                validator: (value) => (value?.length ?? 0) >= 8
                                    ? null
                                    : "密码至少 8 位"),
                            if (_registering) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _code,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration:
                                    const InputDecoration(labelText: "邮箱验证码"),
                                validator: (value) =>
                                    RegExp(r'^\d{6}$').hasMatch(value ?? "")
                                        ? null
                                        : "请输入 6 位验证码",
                              ),
                              OutlinedButton(
                                onPressed: _sendingCode ||
                                        _resendSeconds > 0 ||
                                        _loading
                                    ? null
                                    : _sendCode,
                                child: Text(_sendingCode
                                    ? "正在发送…"
                                    : _resendSeconds > 0
                                        ? "$_resendSeconds秒后重发"
                                        : "发送验证码"),
                              ),
                            ],
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 22),
                            FilledButton(
                                onPressed: _loading ? null : _submit,
                                child: _loading
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : Text(_registering ? "注册并登录" : "登录")),
                            if (!_registering)
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                              builder: (_) => PasswordPage(
                                                  initialEmail:
                                                      _email.text.trim())),
                                        ),
                                child: const Text("忘记密码？"),
                              ),
                            TextButton(
                                onPressed: _loading || _sendingCode
                                    ? null
                                    : () => setState(() {
                                          _registering = !_registering;
                                          _code.clear();
                                          _error = null;
                                        }),
                                child: Text(
                                    _registering ? "已有账号？去登录" : "没有账号？立即注册")),
                          ]))))));
}
