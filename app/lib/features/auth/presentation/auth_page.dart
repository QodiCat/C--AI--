import "package:flutter/material.dart";

import "../../../core/network/api_client.dart";
import "../../../core/network/app_config.dart";
import "../../../core/network/auth_session.dart";
import "../data/auth_repository.dart";

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onAuthenticated});
  final VoidCallback onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final _repository = AuthRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  bool _registering = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = _registering
          ? await _repository.register(_email.text.trim(), _password.text, _nickname.text.trim())
          : await _repository.login(_email.text.trim(), _password.text);
      final data = response["data"] as Map<String, dynamic>;
      await AuthSession.save(data["accessToken"] as String);
      widget.onAuthenticated();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Icon(Icons.checkroom, size: 52),
                        const SizedBox(height: 18),
                        Text("AI衣橱", textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 30),
                        if (_registering) TextFormField(controller: _nickname, decoration: const InputDecoration(labelText: "昵称", prefixIcon: Icon(Icons.person_outline))),
                        if (_registering) const SizedBox(height: 14),
                        TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "邮箱", prefixIcon: Icon(Icons.mail_outline)), validator: (value) => value != null && value.contains("@") ? null : "请输入有效邮箱"),
                        const SizedBox(height: 14),
                        TextFormField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: "密码", prefixIcon: Icon(Icons.lock_outline)), validator: (value) => (value?.length ?? 0) >= 8 ? null : "密码至少 8 位"),
                        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                        const SizedBox(height: 22),
                        FilledButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_registering ? "注册并登录" : "登录")),
                        TextButton(onPressed: _loading ? null : () => setState(() { _registering = !_registering; _error = null; }), child: Text(_registering ? "已有账号？去登录" : "没有账号？立即注册")),
                      ]))))));
}
