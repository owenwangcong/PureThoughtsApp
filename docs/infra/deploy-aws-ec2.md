# 自托管 Supabase 部署指南(AWS EC2)· 对应 PLAN P0.1–P0.5

> 目标:在 AWS EC2 上跑起生产 Supabase,应用我们的 9 个 migration 与 2 个 Edge Function,
> 让 App(经 Codemagic 构建)连上生产环境。
> ⚠️ 红线(PRD §12.5):**服务器不得放中国大陆境内**(ICP 备案 + 宗教内容合规)。

---

## ⚡ 快速通道(推荐):一键脚本

手动只需 3 步,其余全部由脚本自动完成(生成密钥/签 JWT/起服务/HTTPS/migration/函数/cron/种子/备份):

1. **开 EC2**(按下方第 1 章:Ubuntu 24.04、t3.medium、安全组只开 22/80/443、绑 Elastic IP);
2. **DNS**:`api.你的域名` A 记录指向 Elastic IP;
3. **SSH 上服务器跑一条命令**,按提示填域名和 SMTP(E5):

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
| 域名(E2) | 例:`purethoughts.app`,API 用子域 `api.purethoughts.app` |
| 发信服务(E5) | Resend 或 AWS SES 的 SMTP 凭据(注册验证邮件必需) |
| 本机 | 本仓库 + `npx supabase` CLI(已具备) |

**区域选择(P0.1)**:候选 `ap-east-1`(香港)/ `ap-southeast-1`(新加坡)/ `ap-northeast-1`(东京)。
正式选定前,让大陆的同修对三个区域各 ping/加载一次测试页(E6),选延迟最稳的。**先用香港起步即可,数据可迁移。**

---

## 1. 开 EC2 实例

1. **AMI**:Ubuntu Server 24.04 LTS(x86_64)。
2. **规格**:`t3.medium`(2vCPU/4GB)起步可用;预算允许上 `t3.large`(8GB)更从容。
3. **磁盘**:gp3,50 GB。
4. **安全组**(只开这三个,**不开 5432/8000**):
   | 端口 | 来源 | 用途 |
   |---|---|---|
   | 22 | 仅你的 IP | SSH |
   | 80 | 0.0.0.0/0 | TLS 签发(HTTP 挑战) |
   | 443 | 0.0.0.0/0 | API(唯一对外入口) |
5. 分配 **Elastic IP** 并绑定实例。
6. DNS:在域名商处加 A 记录 `api.purethoughts.app → <Elastic IP>`。

---

## 2. 服务器初始化

```bash
ssh -i your-key.pem ubuntu@<Elastic IP>

# Docker 官方安装
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu && newgrp docker

# 基础加固
sudo apt update && sudo apt install -y unattended-upgrades fail2ban
```

---

## 3. 部署 Supabase(官方 Docker Compose)

```bash
git clone --depth 1 https://github.com/supabase/supabase
mkdir -p ~/purethoughts && cp -r supabase/docker/* ~/purethoughts/
cd ~/purethoughts && cp .env.example .env
```

### 3.1 生成密钥(关键!)

```bash
# 40+ 字符的 JWT 密钥与数据库密码
openssl rand -base64 48   # → JWT_SECRET
openssl rand -base64 24   # → POSTGRES_PASSWORD
openssl rand -base64 24   # → DASHBOARD_PASSWORD
```

**ANON_KEY / SERVICE_ROLE_KEY** 必须是用上面 JWT_SECRET 签名的 JWT:
打开官方文档 `supabase.com/docs/guides/self-hosting/docker#generate-api-keys`,
用页面上的生成器分别生成 `anon` 和 `service_role` 两把 key(粘贴你的 JWT_SECRET 生成)。

### 3.2 编辑 `.env`(核心项)

```ini
POSTGRES_PASSWORD=<上面生成>
JWT_SECRET=<上面生成>
ANON_KEY=<生成的 anon JWT>
SERVICE_ROLE_KEY=<生成的 service_role JWT>

SITE_URL=https://api.purethoughts.app
API_EXTERNAL_URL=https://api.purethoughts.app
SUPABASE_PUBLIC_URL=https://api.purethoughts.app

DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=<上面生成>

# 邮件(E5,Resend 示例;SES 同理)
SMTP_ADMIN_EMAIL=no-reply@purethoughts.app
SMTP_HOST=smtp.resend.com
SMTP_PORT=465
SMTP_USER=resend
SMTP_PASS=<Resend API Key>
SMTP_SENDER_NAME=善護念

# 注册开启邮箱确认(生产必开;本地默认关)
ENABLE_EMAIL_AUTOCONFIRM=false
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
api.purethoughts.app {
    reverse_proxy localhost:8000
}
EOF
sudo systemctl restart caddy
```

验证:`curl https://api.purethoughts.app/auth/v1/health` 应返回 GoTrue 信息。
Studio 管理台:`https://api.purethoughts.app`(会弹 Basic Auth,用 DASHBOARD_USERNAME/PASSWORD)。
**不要**把 Studio 分享给任何人;需要更严可在 Caddy 里对 `/project/*` 加 IP 白名单。

---

## 5. 应用本项目的数据库与函数

### 5.1 跑 migration(从你的 Windows 本机,经 SSH 隧道)

```powershell
# 终端 1:开隧道(5432 不对公网开放,这是唯一入库通道)
ssh -i your-key.pem -L 55432:localhost:5432 ubuntu@<Elastic IP>

# 终端 2:项目根目录
npx supabase db push --db-url "postgresql://postgres:<POSTGRES_PASSWORD>@127.0.0.1:55432/postgres"
```

9 个 migration 会按序执行(全部表/RLS/RPC/触发器/事件类型/Realtime 发布)。

### 5.2 生产种子(只种内容,**不种测试账号**)

`supabase/seed.sql` 是本地开发用的(含 test.local 测试账号),**不要整份跑到生产**。
经隧道用 psql 只执行内容部分:

```sql
-- 全局功课清单(17 项,从 seed.sql 复制 practice_types 那一段)
-- 在线经本
insert into public.scriptures (title, web_url, sort_order)
values ('乾隆大藏經', 'https://qldazangjing.com/', 1);
-- 事件类型已由 migration 0008 自带,无需种
```

### 5.3 部署 Edge Functions(delete-account / live-probe)

```bash
# 服务器上:函数目录挂载在 volumes/functions
cd ~/purethoughts
git clone --depth 1 https://github.com/owenwangcong/PureThoughtsApp /tmp/app
cp -r /tmp/app/supabase/functions/* volumes/functions/
docker compose restart functions
# 验证
curl -X POST https://api.purethoughts.app/functions/v1/live-probe \
  -H "Authorization: Bearer <ANON_KEY>" -H "apikey: <ANON_KEY>"
```

### 5.4 pg_cron:开播自动探测(每 5 分钟)

经隧道 psql 执行(把 `<ANON_KEY>` 换成真值):

```sql
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.schedule(
  'live-probe-5min', '*/5 * * * *',
  $$
  select net.http_post(
    url := 'http://kong:8000/functions/v1/live-probe',
    headers := '{"Authorization": "Bearer <ANON_KEY>", "apikey": "<ANON_KEY>", "Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
```

### 5.5 设第一个 App 管理员

用户先在 App 里注册,然后经隧道:

```sql
update public.profiles set is_app_admin = true
where id = (select id from auth.users where email = '<管理员邮箱>');
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

- **UptimeRobot(免费)**:监控 `https://api.purethoughts.app/auth/v1/health`,邮件告警。
- **CloudWatch**:EC2 磁盘 >80%、CPU >90% 各设一条告警。

---

## 8. 让 App 连上生产

### 8.1 Codemagic(正式包,推荐)

Codemagic 控制台 → 项目环境变量组 `production`:

```
SUPABASE_URL      = https://api.purethoughts.app
SUPABASE_ANON_KEY = <生产 ANON_KEY>
SENTRY_DSN        = (可选)
```

触发 `android-release` 工作流 → 产出的 APK/AAB 即连生产。

### 8.2 本机快速验证(可选)

```powershell
cd app
flutter run -d R52W809056B `
  --dart-define=SUPABASE_URL=https://api.purethoughts.app `
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

## 10. 日常运维速查

```bash
docker compose ps                  # 健康状态
docker compose logs -f auth        # 看某服务日志(auth/rest/functions/db...)
docker compose pull && docker compose up -d   # 升级(先在心里默念:备份是新鲜的)
```

**升级纪律**:升级前确认当天备份存在;Supabase 镜像大版本升级先读官方 self-host 变更说明。
