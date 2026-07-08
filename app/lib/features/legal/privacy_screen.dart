import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../l10n/gen/app_localizations.dart';

// 占位文案(基础版,正式版待内容方确认后替换;PLAN E8)
const _privacyHant = '''
【隱私政策(草案)】

我們收集與使用的資料:
• 帳號資料:電子郵箱、顯示名稱,用於登入與群內身份顯示。
• 修行記錄:您提交的報數(功課、數量、日期、備註),僅本群成員可見;個人明細僅您本人可見。
• 偏好設定:語言、字號、所在地區,用於介面顯示與通知送達方式。

我們不會:
• 出售或與第三方共享您的個人資料;
• 在成員之間做任何排名或對比展示。

資料刪除:
• 您可隨時在「設定 → 刪除帳號」刪除帳號;
• 刪除後個人資料將被永久移除,歷史報數將匿名保留於群統計中(不再關聯任何個人)。

如有疑問,請聯繫管理員。
''';

const _privacyHans = '''
【隐私政策(草案)】

我们收集与使用的资料:
• 账号资料:电子邮箱、显示名称,用于登录与群内身份显示。
• 修行记录:您提交的报数(功课、数量、日期、备注),仅本群成员可见;个人明细仅您本人可见。
• 偏好设置:语言、字号、所在地区,用于界面显示与通知送达方式。

我们不会:
• 出售或与第三方共享您的个人资料;
• 在成员之间做任何排名或对比展示。

资料删除:
• 您可随时在「设置 → 删除账号」删除账号;
• 删除后个人资料将被永久移除,历史报数将匿名保留于群统计中(不再关联任何个人)。

如有疑问,请联系管理员。
''';

const _guidelinesHant = '''
【社區規範(草案)】

本應用服務於共修團體,請共同維護清淨和合的氛圍:
• 尊重他人,不發布騷擾、攻擊、歧視性內容;
• 不發布違法、虛假或與修行無關的營銷內容;
• 群名、申請說明、備註、代報名字等均應如實、友善;
• 發現不當內容或用戶,可使用「檢舉」功能,管理員將及時處理;
• 違規者可能被移除內容、移出群組或封禁帳號。
''';

const _guidelinesHans = '''
【社区规范(草案)】

本应用服务于共修团体,请共同维护清净和合的氛围:
• 尊重他人,不发布骚扰、攻击、歧视性内容;
• 不发布违法、虚假或与修行无关的营销内容;
• 群名、申请说明、备注、代报名字等均应如实、友善;
• 发现不当内容或用户,可使用「举报」功能,管理员将及时处理;
• 违规者可能被移除内容、移出群组或封禁账号。
''';

/// 隐私政策 + 社区规范(App 内静态页;上架前替换为正式文案并配官网链接)
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hans = ref.watch(localeProvider).scriptCode == 'Hans';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyPolicy)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(hans ? _privacyHans : _privacyHant),
          const Divider(height: 32),
          Text(hans ? _guidelinesHans : _guidelinesHant),
        ],
      ),
    );
  }
}

/// 首启引导 EULA 步骤用的社区规范文本
String guidelinesText(bool hans) => hans ? _guidelinesHans : _guidelinesHant;
