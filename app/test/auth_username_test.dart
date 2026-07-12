import 'package:flutter_test/flutter_test.dart';
import 'package:pure_thoughts/features/auth/username.dart';

void main() {
  group('用户名映射(PRD v0.5.9)', () {
    test('纯用户名映射为内部邮箱并统一小写', () {
      expect(loginEmailFor('Zhang.san_01'), 'zhang.san_01@u.pure-thoughts.com');
    });

    test('含 @ 的输入按真实邮箱处理(小写、去空白)', () {
      expect(loginEmailFor(' A@B.com '), 'a@b.com');
    });

    test('非法用户名与非法邮箱返回 null', () {
      expect(loginEmailFor('ab'), isNull); // 太短
      expect(loginEmailFor('张三'), isNull); // 非 ASCII
      expect(loginEmailFor('a@b'), isNull); // 缺顶级域
      expect(loginEmailFor(''), isNull);
    });

    test('内部邮箱识别与登录名展示', () {
      expect(isInternalEmail('foo@u.pure-thoughts.com'), isTrue);
      expect(isInternalEmail('foo@gmail.com'), isFalse);
      expect(displayLoginName('foo@u.pure-thoughts.com'), 'foo');
      expect(displayLoginName('foo@gmail.com'), 'foo@gmail.com');
    });
  });
}
