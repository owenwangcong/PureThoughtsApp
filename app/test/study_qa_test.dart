import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_thoughts/core/prefs.dart';
import 'package:pure_thoughts/core/theme/app_theme.dart';
import 'package:pure_thoughts/features/auth/auth_providers.dart';
import 'package:pure_thoughts/features/dashboard/dashboard_providers.dart';
import 'package:pure_thoughts/features/groups/groups_providers.dart';
import 'package:pure_thoughts/features/notifications/notifications_providers.dart';
import 'package:pure_thoughts/features/notifications/notifications_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_compose_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_list_screen.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_providers.dart';
import 'package:pure_thoughts/features/study_qa/study_qa_thread_screen.dart';
import 'package:pure_thoughts/l10n/gen/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 学修问答 UI 与纯逻辑(设计 §8.2 T-APP-01…06、08、10;
/// 触网路径由 study_qa_flow_smoke_test.dart + pgTAP 覆盖)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');

  final testUser = User(
    id: 'u-owner',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-07-30T00:00:00Z',
  );

  Map<String, dynamic> thread({
    String id = 'th-1',
    String userId = 'u-owner',
    String lastRole = 'user',
    String lastAt = '2026-07-30T10:00:00',
    String readAt = '2026-07-30T09:00:00',
    String preview = '打坐時妄念很多怎麼辦?',
    String? asker,
  }) =>
      {
        'id': id,
        'user_id': userId,
        'last_sender_role': lastRole,
        'last_message_at': lastAt,
        'first_message_preview': preview,
        'last_message_preview': preview,
        'user_last_read_at': readAt,
        'created_at': '2026-07-29T08:00:00',
        if (asker != null) 'profiles': {'display_name': asker},
      };

  Future<void> pump(WidgetTester tester, Widget screen,
      {List<dynamic> overrides = const [], GoRouter? router}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final app = router != null
        ? MaterialApp.router(
            routerConfig: router,
            locale: hant,
            supportedLocales: const [hant],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light,
          )
        : MaterialApp(
            locale: hant,
            supportedLocales: const [hant],
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light,
            home: screen,
          );
    await tester.pumpWidget(ProviderScope(
      // 同一测试内多次 pump 时强制重建容器(ProviderScope 不支持换 overrides)
      key: UniqueKey(),
      overrides: [sharedPrefsProvider.overrideWithValue(prefs), ...overrides],
      child: app,
    ));
    await tester.pumpAndSettle();
  }

  GoRouter threadRouter(String threadId) => GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => StudyQaThreadScreen(threadId: threadId),
        ),
      ]);

  group('纯逻辑', () {
    test('未读红点:管理员最后发言且晚于已读位点', () {
      expect(qaThreadUnread(thread(lastRole: 'admin')), isTrue);
      expect(
          qaThreadUnread(
              thread(lastRole: 'admin', readAt: '2026-07-30T11:00:00')),
          isFalse);
      expect(qaThreadUnread(thread(lastRole: 'user')), isFalse);
    });

    test('待回覆状态 = 最后发言方是用户', () {
      expect(qaThreadPending(thread(lastRole: 'user')), isTrue);
      expect(qaThreadPending(thread(lastRole: 'admin')), isFalse);
    });

    test('语境判定(P8.6):?as=admin 或非线程主人 → 管理员语境', () {
      expect(qaAdminContext(asAdmin: false, threadOwnerId: 'u1', myId: 'u1'),
          isFalse);
      expect(qaAdminContext(asAdmin: true, threadOwnerId: 'u1', myId: 'u1'),
          isTrue); // 管理员从管理 tab 进自己的线程:仍是管理员身份
      expect(qaAdminContext(asAdmin: false, threadOwnerId: 'u1', myId: 'a1'),
          isTrue); // 非主人(RLS 已证明是管理员)
      expect(qaContextRole(true), 'admin');
      expect(qaContextRole(false), 'user');
    });

    test('气泡分侧按角色对语境(P8.6):同一人自问自答也问答分明', () {
      expect(qaBubbleOnRight('user', false), isTrue); // 提问人看自己的问题:右
      expect(qaBubbleOnRight('admin', false), isFalse); // 提问人看管理员回复:左
      expect(qaBubbleOnRight('admin', true), isTrue); // 管理员语境看回复:右
      expect(qaBubbleOnRight('user', true), isFalse); // 管理员语境看问题:左
    });
  });

  testWidgets('T-APP-01 列表页三态:骨架/空态/错误重试', (tester) async {
    // 空态
    await pump(tester, const StudyQaListScreen(), overrides: [
      myProfileProvider.overrideWith((ref) => null),
      qaThreadsProvider.overrideWith((ref) async => []),
    ]);
    expect(find.text('還沒有提問。向管理員請教學修問題吧。'), findsOneWidget);

    // 错误态 → 重试按钮
    await pump(tester, const StudyQaListScreen(), overrides: [
      myProfileProvider.overrideWith((ref) => null),
      qaThreadsProvider.overrideWith((ref) async => throw Exception('boom')),
    ]);
    expect(find.text('載入失敗,請重試'), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);

    // 加载态(悬置的 Future → 骨架屏);pump 一帧不 settle
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        myProfileProvider.overrideWith((ref) => null),
        qaThreadsProvider.overrideWith(
            (ref) => Completer<List<Map<String, dynamic>>>().future),
      ],
      key: UniqueKey(),
      child: MaterialApp(
        locale: hant,
        supportedLocales: const [hant],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.light,
        home: const StudyQaListScreen(),
      ),
    ));
    await tester.pump();
    expect(find.byType(FadeTransition), findsWidgets); // SkeletonList 在场
  });

  testWidgets('T-APP-02 列表行:状态章与未读红点', (tester) async {
    await pump(tester, const StudyQaListScreen(), overrides: [
      myProfileProvider.overrideWith((ref) => null),
      qaThreadsProvider.overrideWith((ref) async => [
            thread(id: 'a', lastRole: 'admin'), // 已回覆 + 未读(last > read)
            thread(id: 'b', lastRole: 'user', preview: '誦經迴向給家人是否如法?'),
          ]),
    ]);
    expect(find.text('已回覆'), findsOneWidget);
    expect(find.text('待回覆'), findsOneWidget);
    // 未读红点只在 a 行
    expect(
        find.byWidgetPredicate(
            (w) => w is Icon && w.icon == Icons.circle && w.size == 10),
        findsOneWidget);
  });

  testWidgets('T-APP-03 新提问页:空内容发送钮禁用;有内容启用;2000 字上限', (tester) async {
    await pump(tester, const StudyQaComposeScreen());
    // FilledButton.icon 的 runtimeType 是私有子类,须用 bySubtype
    FilledButton button() =>
        tester.widget<FilledButton>(find.bySubtype<FilledButton>());
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '請問如何安排早晚課?');
    await tester.pump();
    expect(button().onPressed, isNotNull);

    // TextField maxLength 2000(硬上限)
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 2000);
  });

  test('T-APP-03 上限错误映射:QA_PENDING_LIMIT → 专属文案', () async {
    final l10n = await AppLocalizations.delegate.load(hant);
    expect(
      qaErrorText(
          l10n,
          const PostgrestException(
              message: 'QA_PENDING_LIMIT', code: 'P0001')),
      l10n.studyQaLimitHit,
    );
    // 其他错误走通用映射,不误吞
    expect(qaErrorText(l10n, const PostgrestException(message: 'x', code: '42501')),
        isNot(l10n.studyQaLimitHit));
  });

  testWidgets('T-APP-04 会话页:气泡分侧 + 管理員署名', (tester) async {
    // 以管理员视角看他人线程(不触发 markRead 的触网路径)
    final adminUser = User(
      id: 'admin-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-07-30T00:00:00Z',
    );
    await pump(tester, const StudyQaThreadScreen(threadId: 'th-1'), overrides: [
      currentUserProvider.overrideWith((ref) => adminUser),
      qaThreadProvider('th-1').overrideWith((ref) async => thread()),
      qaMessagesProvider('th-1').overrideWith((ref) async => [
            {
              'id': 'm1',
              'sender_id': 'u-owner',
              'sender_role': 'user',
              'body': '打坐時妄念很多怎麼辦?',
              'created_at': '2026-07-30T09:00:00',
            },
            {
              'id': 'm2',
              'sender_id': 'admin-2',
              'sender_role': 'admin',
              'sender_name': '慧明師父', // v0.5.20:管理员署显示名
              'body': '妄念來去不隨。',
              'created_at': '2026-07-30T09:30:00',
            },
            {
              'id': 'm3',
              'sender_id': 'admin-1',
              'sender_role': 'admin',
              // sender_name 缺失(如已删号)→ 回退「管理員」
              'body': '補充:安住呼吸。',
              'created_at': '2026-07-30T10:00:00',
            },
          ]),
    ]);
    // P8.6:分侧按角色对语境——管理员语境(非主人)下,admin 消息一律右,
    // user 消息左;与哪位管理员发的无关
    Alignment alignOf(String text) => tester
        .widget<Align>(find
            .ancestor(of: find.text(text), matching: find.byType(Align))
            .first)
        .alignment as Alignment;
    expect(alignOf('打坐時妄念很多怎麼辦?'), Alignment.centerLeft);
    expect(alignOf('妄念來去不隨。'), Alignment.centerRight);
    expect(alignOf('補充:安住呼吸。'), Alignment.centerRight);
    // 管理员消息署显示名(v0.5.20),取不到回退「管理員」;
    // 管理员语境下用户消息署「提問人」
    expect(find.text('慧明師父'), findsOneWidget);
    expect(find.text('管理員'), findsOneWidget);
    expect(find.text('提問人'), findsOneWidget);
  });

  testWidgets('T-APP-04c P8.6 回归:自问自答问答分明(提问人语境)', (tester) async {
    // 同一账号手机提问、后台以管理员身份回复:提问人语境下,
    // 自己的问题在右、管理员回复在左并署名——即使 sender_id 都是本人
    await pump(tester, const StudyQaThreadScreen(threadId: 'th-1'), overrides: [
      currentUserProvider.overrideWith((ref) => testUser),
      qaThreadProvider('th-1').overrideWith((ref) async => thread()),
      qaMessagesProvider('th-1').overrideWith((ref) async => [
            {
              'id': 'm1',
              'sender_id': 'u-owner',
              'sender_role': 'user',
              'body': '打坐時妄念很多怎麼辦?',
              'created_at': '2026-07-30T09:00:00',
            },
            {
              'id': 'm2',
              'sender_id': 'u-owner', // 本人在后台以管理员身份自答
              'sender_role': 'admin',
              'body': '妄念來去不隨。',
              'created_at': '2026-07-30T09:30:00',
            },
          ]),
    ]);
    Alignment alignOf(String text) => tester
        .widget<Align>(find
            .ancestor(of: find.text(text), matching: find.byType(Align))
            .first)
        .alignment as Alignment;
    expect(alignOf('打坐時妄念很多怎麼辦?'), Alignment.centerRight);
    expect(alignOf('妄念來去不隨。'), Alignment.centerLeft);
    expect(find.text('管理員'), findsOneWidget);
    // 提问人语境下自己的消息不署「提問人」
    expect(find.text('提問人'), findsNothing);
  });

  testWidgets('T-APP-05 删除流:菜单 → 确认对话框 → 取消保留', (tester) async {
    final adminUser = User(
      id: 'admin-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-07-30T00:00:00Z',
    );
    await pump(tester, const StudyQaThreadScreen(threadId: 'th-1'), overrides: [
      currentUserProvider.overrideWith((ref) => adminUser),
      qaThreadProvider('th-1').overrideWith((ref) async => thread()),
      qaMessagesProvider('th-1').overrideWith((ref) async => []),
    ]);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('刪除提問').last);
    await tester.pumpAndSettle();
    expect(find.text('刪除後問答內容將永久消失,無法恢復。確定刪除?'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('刪除後問答內容將永久消失,無法恢復。確定刪除?'), findsNothing);
  });

  testWidgets('T-APP-04b 已删线程空态「該提問已刪除」', (tester) async {
    // 空态动作用到 context.canPop(),需真实 GoRouter 上下文
    await pump(tester, const SizedBox.shrink(),
        router: threadRouter('gone'),
        overrides: [
          currentUserProvider.overrideWith((ref) => testUser),
          qaThreadProvider('gone').overrideWith((ref) async => null),
          qaMessagesProvider('gone').overrideWith((ref) async => []),
        ]);
    expect(find.text('該提問已刪除'), findsOneWidget);
  });

  testWidgets('T-APP-06 通知中心:qa 类型渲染无正文 + 深链会话页', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const NotificationsScreen()),
      GoRoute(
        path: '/study-qa/:tid',
        builder: (context, state) => Scaffold(
            body: Text('thread:${state.pathParameters['tid']}'
                ':${state.uri.queryParameters['as'] ?? 'user'}')),
      ),
    ]);
    await pump(tester, const SizedBox.shrink(), router: router, overrides: [
      currentUserProvider.overrideWith((ref) => testUser),
      allPracticeTypesMapProvider.overrideWith((ref) async => {}),
      myGroupsProvider.overrideWith((ref) async => []),
      // 已读(notification_reads 非空)→ 不触发标记已读的触网路径
      myNotificationsProvider.overrideWith((ref) async => [
            {
              'id': 'n1',
              'scope': 'user',
              'target_id': 'u-owner',
              'title': '',
              'body': null,
              'type': 'qa_reply',
              'payload': {'thread_id': 'th-9'},
              'created_at': '2026-07-30T10:00:00',
              'notification_reads': [
                {'read_at': '2026-07-30T10:01:00'}
              ],
            },
            {
              'id': 'n2',
              'scope': 'user',
              'target_id': 'admin-1',
              'title': '',
              'body': null,
              'type': 'qa_question',
              'payload': {'thread_id': 'th-9'},
              'created_at': '2026-07-30T09:00:00',
              'notification_reads': [
                {'read_at': '2026-07-30T09:01:00'}
              ],
            },
          ]),
    ]);
    expect(find.text('您的提問有新回覆'), findsOneWidget);
    expect(find.text('有新的學修提問'), findsOneWidget);
    // 副标题不含任何正文(qa 行副标题只有时间行)
    expect(find.textContaining('妄念'), findsNothing);
    // 点击深链到会话页:qa_reply 提问人语境
    await tester.tap(find.text('您的提問有新回覆'));
    await tester.pumpAndSettle();
    expect(find.text('thread:th-9:user'), findsOneWidget);
    // qa_question 管理员语境(P8.6:?as=admin)
    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('有新的學修提問'));
    await tester.pumpAndSettle();
    expect(find.text('thread:th-9:admin'), findsOneWidget);
  });

  testWidgets('T-APP-08/10 管理员视图:待回覆/全部/我的 三 tab + 提问人名 + 全线程可删', (tester) async {
    await pump(tester, const StudyQaListScreen(), overrides: [
      myProfileProvider
          .overrideWith((ref) => {'is_app_admin': true, 'id': 'admin-1'}),
      qaThreadsProvider.overrideWith((ref) async => [
            thread(id: 'a', lastRole: 'user', asker: '王師姐'),
            thread(
                id: 'b',
                userId: 'admin-1', // 管理员自己的提问
                lastRole: 'admin',
                asker: '李師兄',
                preview: '誦經迴向如法嗎?'),
          ]),
    ]);
    // 三个 tab(P8.6:管理员也有自己的提问人视角)
    expect(find.widgetWithText(Tab, '待回覆'), findsOneWidget);
    expect(find.widgetWithText(Tab, '全部'), findsOneWidget);
    expect(find.widgetWithText(Tab, '我的提問'), findsOneWidget);
    // 默认「待回覆」tab 只显示 a,含提问人名
    expect(find.text('王師姐'), findsOneWidget);
    expect(find.text('誦經迴向如法嗎?'), findsNothing);
    // 切「全部」tab 显示两条
    await tester.tap(find.widgetWithText(Tab, '全部'));
    await tester.pumpAndSettle();
    expect(find.text('王師姐'), findsOneWidget);
    expect(find.text('李師兄'), findsOneWidget);
    // 切「我的提問」tab 只显示本人线程,提问人语境不显示名字
    await tester.tap(find.widgetWithText(Tab, '我的提問'));
    await tester.pumpAndSettle();
    expect(find.text('誦經迴向如法嗎?'), findsOneWidget);
    expect(find.text('打坐時妄念很多怎麼辦?'), findsNothing);
    expect(find.text('李師兄'), findsNothing);

    // 管理员打开任意线程都有删除入口(T-APP-10)
    final adminUser = User(
      id: 'admin-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-07-30T00:00:00Z',
    );
    await pump(tester, const StudyQaThreadScreen(threadId: 'b'), overrides: [
      currentUserProvider.overrideWith((ref) => adminUser),
      qaThreadProvider('b').overrideWith((ref) async => thread(id: 'b')),
      qaMessagesProvider('b').overrideWith((ref) async => []),
    ]);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });
}
