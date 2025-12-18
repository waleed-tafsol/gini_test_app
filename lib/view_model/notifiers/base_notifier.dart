import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:tafsol_genie_app/exceptions/app_exception.dart';

abstract class BaseNotifier<State> extends Notifier<State> {
  final State initialState;

  BaseNotifier(this.initialState);

  @override
  State build() {
    init();
    ref.onDispose(dispose);
    return initialState;
  }

  @mustCallSuper
  void init() {
    log('$runtimeType INITIALIZED', name: 'RIVERPOD');
  }

  Future<T?> runSafely<T>(AsyncValueGetter<T> action) async {
    try {
      return await action.call();
    } on AppException catch (e, s) {
      onError(e.message);
      log(e.message, stackTrace: s);
      return null;
    } catch (e, s) {
      onError(e.toString());
      log(e.toString(), stackTrace: s);
      return null;
    }
  }

  @mustCallSuper
  void onError(String msg) {
    Fluttertoast.showToast(msg: msg.replaceAll('Exception:', ''));
  }

  @mustCallSuper
  void dispose() {
    log('$runtimeType DISPOSED', name: 'RIVERPOD');
  }
}
