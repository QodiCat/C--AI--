import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_config.dart';
import '../../../core/network/auth_session.dart';
import '../data/auth_repository.dart';

class PasswordPage extends StatefulWidget {
  const PasswordPage(
      {super.key,
      this.changePassword = false,
      this.initialEmail = '',
      this.repository});
  final bool changePassword;
  final String initialEmail;
  final AuthRepository? repository;

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _current = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _repository = widget.repository ??
      AuthRepository(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  Timer? _timer;
  int _seconds = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in [_email, _current, _code, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = '请输入有效邮箱');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repository.sendPasswordResetCode(_email.text.trim());
      if (!mounted) return;
      setState(() => _seconds = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => _seconds--);
        if (_seconds <= 0) timer.cancel();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('如果该邮箱已注册，验证码将发送到邮箱，10 分钟内有效')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '无法连接服务，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.changePassword) {
        await _repository.changePassword(_current.text, _password.text);
      } else {
        await _repository.resetPassword(
            _email.text.trim(), _code.text.trim(), _password.text);
      }
      await AuthSession.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('密码已更新，请使用新密码登录')));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = '无法完成操作，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.changePassword ? '修改密码' : '忘记密码')),
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                      key: _form,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.changePassword
                                ? '修改后所有设备都需要重新登录。'
                                : '通过注册邮箱验证码重置密码，重置后所有设备都需要重新登录。'),
                            const SizedBox(height: 20),
                            if (widget.changePassword)
                              TextFormField(
                                  controller: _current,
                                  enabled: !_busy,
                                  obscureText: true,
                                  decoration:
                                      const InputDecoration(labelText: '当前密码'),
                                  validator: (v) =>
                                      (v?.isEmpty ?? true) ? '请输入当前密码' : null)
                            else ...[
                              TextFormField(
                                  controller: _email,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration:
                                      const InputDecoration(labelText: '注册邮箱'),
                                  validator: (v) =>
                                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                              .hasMatch(v?.trim() ?? '')
                                          ? null
                                          : '请输入有效邮箱'),
                              TextFormField(
                                  controller: _code,
                                  enabled: !_busy,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration:
                                      const InputDecoration(labelText: '邮箱验证码'),
                                  validator: (v) => RegExp(r'^\d{6}$')
                                          .hasMatch(v?.trim() ?? '')
                                      ? null
                                      : '请输入 6 位验证码'),
                              OutlinedButton(
                                  onPressed:
                                      _busy || _seconds > 0 ? null : _sendCode,
                                  child: Text(_seconds > 0
                                      ? '$_seconds秒后重发'
                                      : '发送重置验证码')),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                                controller: _password,
                                enabled: !_busy,
                                obscureText: true,
                                decoration:
                                    const InputDecoration(labelText: '新密码'),
                                validator: (v) {
                                  final length = utf8.encode(v ?? '').length;
                                  if (length < 8 || length > 72) {
                                    return '密码需为 8–72 字节';
                                  }
                                  if (widget.changePassword &&
                                      v == _current.text) {
                                    return '新密码不能与当前密码相同';
                                  }
                                  return null;
                                }),
                            const SizedBox(height: 14),
                            TextFormField(
                                controller: _confirm,
                                enabled: !_busy,
                                obscureText: true,
                                decoration:
                                    const InputDecoration(labelText: '确认新密码'),
                                validator: (v) =>
                                    v == _password.text ? null : '两次密码不一致'),
                            if (_error != null)
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            const SizedBox(height: 24),
                            FilledButton(
                                onPressed: _busy ? null : _submit,
                                child: Text(_busy
                                    ? '正在提交…'
                                    : widget.changePassword
                                        ? '确认修改'
                                        : '重置密码')),
                          ])),
                ))),
      );
}
