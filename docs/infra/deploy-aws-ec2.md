# 自托管 Supabase 部署指南(AWS EC2)· 对应 PLAN P0.1–P0.5

> 目标:在 AWS EC2 上跑起生产 Supabase,应用我们的 9 个 migration 与 2 个 Edge Function,
> 让 App(经 Codemagic 构建)连上生产环境。
> ⚠️ 红线(PRD §12.5):**服务器不得放中国大陆境内**(ICP 备案 + 宗教内容合规)。

---

## ⚡ 快速通道(推荐):一键脚本

手动只需 3 步,其余全部由脚本自动完成(生成密钥/起服务/HTTPS/migration/函数/cron/种子/备份):

1. **开 EC2**(按下方第 1 章:Ubuntu 24.04 ARM、t4g.medium、安全组只开 22/80/443、绑 Elastic IP);
2. **DNS**:`api.pure-thoughts.com` A 记录指向 Elastic IP;
3. **SSH 上服务器跑一条命令**,模式选 `1`,按提示填域名和 SMTP(E5):

```bash
curl -fsSL https://raw.githubusercontent.com/owenwangcong/PureThoughtsApp/master/scripts/deploy/setup-supabase-ec2.sh -o setup.sh
bash setup.sh
```

跑完把屏幕提示的凭据文件存进密码管理器,再做收尾 3 步(Codemagic 填环境组 / 设首个管理员 / 恢复演练)。
以下手动章节作为脚本的**原理说明与排障参考**。

---

## 0. 事前准备(需要你先有)

| 项 | 说明 |
|---|---|
| AWS 账号 | 可开 EC2 的权限 |
| 域名(E2) | ✅ `pure-thoughts.com`(现有),API 用子域 `api.pure-thoughts.com`,证书 certbot 单独签 |
| 发信服务(E5) | Resend 或 AWS SES 的 SMTP 凭据(注册验证邮件必需) |
| 本机 | 本仓库 + `npx supabase` CLI(已具备) |

**区域选择(P0.1)**:✅ 2026-07-11 定案 **`ap-southeast-1`(新加坡)**——与现有 pure-thoughts.com
服务器同区,该服务器多年服务同一批用户(含大陆),可达性有实践背书;大陆网络正式复核保留在 E6。

---

## 1. 开 EC2 实例

1. **AMI**:Ubuntu Server 24.04 LTS(**推荐 64-bit ARM** 配 t4g 实例;x86_64 配 t3)。
2. **规格**:推荐 **`t4g.medium`**(ARM,2vCPU/4GB,新加坡约 30 USD/月,比 t3.medium 省约 20%,
   Supabase 镜像原生支持 ARM);网站将来迁入(附 B)后升 `t4g.large`(8GB)。
   换规格 = 停机改类型再开机约 2 分钟,Elastic IP 不变,随时可调。
3. **磁盘**:gp3,50 GB。
4. **安全组**(只开这三个,**不开 5432/8000**):
   | 端口 | 来源 | 用途 |
   |---|---|---|
   | 22 | 仅你的 IP | SSH |
   | 80 | 0.0.0.0/0 | TLS 签发(HTTP 挑战) |
   | 443 | 0.0.0.0/0 | API(唯一对外入口) |
5. 分配 **Elastic IP** 并绑定实例。
6. DNS:在域名商处加 A 记录 `api.pure-thoughts.com → <Elastic IP>`。

---

## 2. 服务器初始化

```bash
ssh -i your-key.pem ubuntu@<Elastic IP>

# Docker 官方安装
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
# ⚠️ 组成员要退出重连 SSH 才生效;不重连的话 docker 命令会报
#    "permission denied ... docker.sock",临时可在命令前加 sudo

# 基础加固
sudo apt update && sudo apt install -y unattended-upgrades fail2ban
```

---

## 3. 部署 Supabase(官方 Docker Compose)

```bash
git clone --depth 1 https://github.com/supabase/supabase
# ⚠️ 用 /. 结尾,不要用 /*(* 不匹配 .env.example 等隐藏文件)
mkdir -p ~/purethoughts && cp -r supabase/docker/. ~/purethoughts/
cd ~/purethoughts && cp .env.example .env
```

### 3.1 生成密钥(关键!)

上游 2026 年新结构自带官方生成器,一条命令生成全部密钥
(JWT_SECRET、ANON/SERVICE_ROLE JWT、各加密键、DB 与管理台密码)并写入 `.env`:

```bash
bash utils/generate-keys.sh --update-env
```

(旧结构才需要手动 openssl + 官方网页生成器,已过时。)

### 3.2 编辑 `.env`(生成器没覆盖的部分)

密钥类(POSTGRES_PASSWORD / JWT_SECRET / ANON_KEY / SERVICE_ROLE_KEY / DASHBOARD_PASSWORD)
已由 3.1 写好,手动只需改:

```ini
# 站点 URL:把默认值里的 http://localhost:8000(或 :3000)换成 https://api.pure-thoughts.com,
# ⚠️ 保留默认值自带的路径(如新版 API_EXTERNAL_URL 带 /auth/v1,只换协议+主机)
SITE_URL=…
API_EXTERNAL_URL=…
SUPABASE_PUBLIC_URL=https://api.pure-thoughts.com

# 邮件(E5,Resend 示例;SES 同理)
SMTP_ADMIN_EMAIL=no-reply@pure-thoughts.com
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_USER=resend
SMTP_PASS=<Resend API Key>
SMTP_SENDER_NAME=善護念

# 注册免邮箱验证(PRD v0.5.9:用户名+密码体系,邮箱选填仅作找回)
ENABLE_EMAIL_AUTOCONFIRM=true
```

> 💾 **把整份 `.env` 存进密码管理器**——它就是生产环境的全部钥匙。

### 3.3 启动

```bash
docker compose pull
docker compose up -d
docker compose ps   # 全部 healthy 才算成
```

---

## 4. TLS 反向代理(Caddy,自动续证书)

```bash
sudo apt install -y caddy
sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
api.pure-thoughts.com {
    reverse_proxy localhost:8000
}
EOF
sudo systemctl restart caddy
```

验证:`curl https://api.pure-thoughts.com/auth/v1/health` 应返回 GoTrue 信息。
Studio 管理台:`https://api.pure-thoughts.com`(会弹 Basic Auth,用 DASHBOARD_USERNAME/PASSWORD)。
**不要**把 Studio 分享给任何人;需要更严可在 Caddy 里对 `/project/*` 加 IP 白名单。

---

## 5. 应用本项目的数据库与函数(脚本已全部自动完成)

> 脚本在服务器本机依序完成:执行 `supabase/migrations/*.sql` 建表/RLS/触发器
>(带 `_applied_migrations` 追踪表,可重复执行)→ 种生产内容(17 个功课项 + 经本,
> **不含测试账号**;本地 `seed.sql` 只属于本地开发)→ 部署 Edge Functions
>(delete-account / live-probe)→ 注册 pg_cron 开播探测(每 5 分钟)。
> 手动验证函数:`curl -X POST https://api.pure-thoughts.com/functions/v1/live-probe -H "Authorization: Bearer <ANON_KEY>" -H "apikey: <ANON_KEY>"`

**唯一需要手动的一步——设第一个 App 管理员**(你在 App 里注册账号后,服务器上执行):

```bash
sudo docker exec supabase-db psql -U postgres -c \
  "update public.profiles set is_app_admin = true where id = (select id from auth.users where email = '<管理员邮箱>')"
```

---

## 6. 备份(P0.4,硬门槛:必须做一次恢复演练)

```bash
# 建 S3 桶(不同区域!)pt-backups,实例挂 IAM 角色允许 s3:PutObject
sudo apt install -y awscli
sudo tee /usr/local/bin/pt-backup.sh > /dev/null <<'EOF'
#!/bin/bash
set -e
F=/tmp/pt-$(date +%F).sql.gz
docker exec supabase-db pg_dumpall -U postgres | gzip > $F
aws s3 cp $F s3://pt-backups/db/ && rm $F
EOF
sudo chmod +x /usr/local/bin/pt-backup.sh
# 每日 03:00
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/pt-backup.sh") | crontab -
```

**恢复演练**(上线前做一次):开一台临时 EC2 → 同法装 Supabase → `gunzip -c dump.sql.gz | docker exec -i supabase-db psql -U postgres` → App 指向它验证登录/报数正常 → 销毁临时机,在 PLAN 记录日期。

---

## 7. 监控(P0.5)

- **UptimeRobot(免费)**:监控 `https://api.pure-thoughts.com/auth/v1/health`,邮件告警。
- **CloudWatch**:EC2 磁盘 >80%、CPU >90% 各设一条告警。

---

## 8. 让 App 连上生产

### 8.1 Codemagic(正式包,推荐)

Codemagic 控制台 → 项目环境变量组 `production`:

```
SUPABASE_URL      = https://api.pure-thoughts.com
SUPABASE_ANON_KEY = <生产 ANON_KEY>
SENTRY_DSN        = (可选)
```

触发 `android-release` 工作流 → 产出的 APK/AAB 即连生产。

### 8.2 本机快速验证(可选)

```powershell
cd app
flutter run -d R52W809056B `
  --dart-define=SUPABASE_URL=https://api.pure-thoughts.com `
  --dart-define=SUPABASE_ANON_KEY=<生产 ANON_KEY>
```

---

## 9. 验收清单(对应 PLAN P0.2–P0.5 的 DoD)

- [ ] `curl https://api.../auth/v1/health` 返回 200(P0.2)
- [ ] App 注册 → 收到验证邮件 → 登录成功(P0.3,SMTP 通)
- [ ] 建群 → 报数 → 群统计正确(RLS 生产生效)
- [ ] `live-probe` cron 在跑:`select * from cron.job_run_details order by start_time desc limit 5;`
- [ ] 备份文件出现在 S3 且**完成一次恢复演练**(P0.4)
- [ ] UptimeRobot 告警测试通过(P0.5)
- [ ] **大陆真实网络实测**(E6):登录/报数/拉通知的延迟可接受(P0.1 定案)
- [ ] Codemagic 出的正式 APK 在真机连生产全流程走通

---

## 附 A:与旧 Bitnami 服务器共置(❌ 2026-07-11 实测否决)

> **否决原因**:旧服务器为 Ubuntu 16.04 xenial(2021 年 EOL,内核 4.4 时代)。Docker 官方源已无
> xenial 包;即便装旧版 Docker,Supabase 现代镜像(新 glibc 依赖 `clone3` 等新系统调用)在老内核上
> 无法可靠运行。改走正文的独立新 EC2 方案。
> 脚本的模式 2(共置 Apache:预检内存/端口、Kong 改 8010/8453、跳过 Caddy)保留为通用能力;
> 当时的 certbot/vhost 详细步骤见 git 历史(commit `0e6432c`)。

**旧服务器待清理**(DNS 指向新机之后):

```bash
sudo certbot delete --cert-name api.pure-thoughts.com   # 否则续期失败会一直发告警邮件
# 并删除 httpd.conf 里新增的两个 api.pure-thoughts.com vhost,重启 Apache
```

---

## 附 B:旧服务器网站迁移到新 EC2(WordPress / Discuz / FastAPI,择期)

> 目标:旧机(Ubuntu 16.04 EOL)上的网站分阶段迁到新 EC2,全部迁完退掉旧机。
> 原则:① **不整体拷 `/opt/bitnami`**(绑定旧系统库,新机跑不起来),迁数据、Docker 重建运行时;
> ② 新机 **Caddy 做唯一前门**,所有域名证书全自动,不再装 Apache;
> ③ 分阶段,**网站迁移不阻塞 App 上线**(阶段 1 = Supabase,即本文正文)。

### B.1 WordPress(pure-thoughts.com)

```bash
# 旧机导出(DB 密码看 wp-config.php 的 DB_ 项)
/opt/bitnami/mysql/bin/mysqldump -u root -p bitnami_wordpress > wp.sql
tar czf wp-content.tgz -C /opt/bitnami/wordpress wp-content
scp wp.sql wp-content.tgz ubuntu@<新机IP>:~
```

新机:官方 `wordpress` + `mariadb` 镜像起 compose(监听 127.0.0.1:8080),导入 `wp.sql`,
`wp-content` 挂进卷;Caddyfile 追加:

```
pure-thoughts.com, www.pure-thoughts.com {
    reverse_proxy 127.0.0.1:8080
}
```

`sudo systemctl restart caddy` → DNS `pure-thoughts.com` A 记录指向新机(域名不变,无需站内搜索替换)。

### B.2 Discuz(bbs.pure-thoughts.com)

同法:`php:8.x-apache` 容器 + 数据库导入 + 站点文件卷挂载;Caddy 加 `bbs.pure-thoughts.com` 块。

### B.3 FastAPI(127.0.0.1:8000 / 8001)

代码拷过来容器化(或新机重建 venv + systemd);若有对外域名同样走 Caddy 反代。

### B.4 收尾

- 全部验证通过后退掉旧机(留最后一份旧机全量备份再销毁)。
- 内存:只跑 Supabase 用 t4g.medium(4GB);网站全迁入后建议升 t4g.large(8GB)——
  EC2 换规格 = 停机改类型再开机,约 2 分钟,Elastic IP 不变。

---

## 10. 日常运维速查

```bash
docker compose ps                  # 健康状态
docker compose logs -f auth        # 看某服务日志(auth/rest/functions/db...)
docker compose pull && docker compose up -d   # 升级(先在心里默念:备份是新鲜的)
```

**以后有新 migration 要推生产**(本地验证过后)——**推荐:重跑一键脚本**,它只补
`_applied_migrations` 记账表里没有的新文件并记账,可重复执行:

```bash
# 私有仓库:先从本机 scp 最新 supabase/ 目录到 ~/PureThoughtsApp,再:
bash ~/PureThoughtsApp/scripts/deploy/setup-supabase-ec2.sh   # 模式 1,密钥已存在会自动跳过生成
```

⚠️ 不要用绕过记账的方式推(手动 psql 单文件、`supabase db push`)——`_applied_migrations`
不知道该文件已应用,下次重跑脚本会重复执行报错中断。若确需手动执行,补一条记账:

```bash
sudo docker exec supabase-db psql -U postgres -c \
  "insert into public._applied_migrations (name) values ('<文件名.sql>')"
```

**结构一致性纪律**:生产 Studio 只改**数据**,永不改**结构**;结构变更一律
"新 migration 文件 → 本地 `db reset` + `test db` 验证 → 推生产",保证本地与生产同构。
核对两边结构:本地 `npx supabase db dump --local --schema public`,
生产 `sudo docker exec supabase-db pg_dump -U postgres --schema-only --schema public postgres`,diff 之。

**管理员代重置密码**(PRD v0.5.9:纯用户名账号无邮箱,忘记密码由管理员协助;
纯用户名账号的 Auth 邮箱 = `<用户名>@u.pure-thoughts.com`):

```bash
sudo docker exec supabase-db psql -U postgres -c \
  "update auth.users set encrypted_password = crypt('新密码', gen_salt('bf')) where email = '<用户名>@u.pure-thoughts.com'"
```

**升级纪律**:升级前确认当天备份存在;Supabase 镜像大版本升级先读官方 self-host 变更说明。
