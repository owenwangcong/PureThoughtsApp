#!/bin/bash
# ============================================================================
# 善护念 PureThoughts · 自托管 Supabase 一键部署(Ubuntu 24.04,AWS EC2)
#
# 前提:1) EC2 已开(安全组只开 22/80/443)  2) 域名 A 记录已指向本机公网 IP
# 用法:ssh 到服务器后执行
#   curl -fsSL https://raw.githubusercontent.com/owenwangcong/PureThoughtsApp/master/scripts/deploy/setup-supabase-ec2.sh | bash
# 或把本文件拷上去 bash 运行。全程约 5-10 分钟。
#
# 自动完成:Docker + Supabase(官方 compose)+ 密钥生成(含 JWT 签名)
#   + Caddy HTTPS + 本项目 9 个 migration + 2 个 Edge Function
#   + pg_cron 开播探测 + 生产内容种子 + 每日备份
# ============================================================================
set -euo pipefail

APP_REPO="https://github.com/owenwangcong/PureThoughtsApp.git"
DIR="$HOME/purethoughts"

echo "=============================================="
echo " 善护念 Supabase 一键部署"
echo "=============================================="
read -rp "API 域名(A 记录须已指向本机,如 api.purethoughts.app): " DOMAIN
read -rp "SMTP 主机(如 smtp.resend.com): " SMTP_HOST
read -rp "SMTP 端口 [465]: " SMTP_PORT; SMTP_PORT=${SMTP_PORT:-465}
read -rp "SMTP 用户名(Resend 填 resend): " SMTP_USER
read -rsp "SMTP 密码/API Key: " SMTP_PASS; echo
read -rp "发件邮箱(如 no-reply@purethoughts.app): " SMTP_FROM
read -rp "S3 备份桶名(留空则仅备份到本机 ~/backups): " S3_BUCKET

# ---------------------------------------------------------------- 依赖
if ! command -v docker >/dev/null; then
  echo "==> 安装 Docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi
sudo apt-get update -qq
sudo apt-get install -y -qq caddy git openssl >/dev/null

# ---------------------------------------------------------------- 取官方 compose
echo "==> 下载 Supabase 官方 Docker 配置"
rm -rf /tmp/sb && git clone --depth 1 -q https://github.com/supabase/supabase /tmp/sb
mkdir -p "$DIR" && cp -rn /tmp/sb/docker/* "$DIR"/ && cd "$DIR"
[ -f .env ] || cp .env.example .env

# ---------------------------------------------------------------- 生成密钥
echo "==> 生成密钥与 JWT"
JWT_SECRET=$(openssl rand -hex 32)
PG_PASS=$(openssl rand -hex 16)
DASH_PASS=$(openssl rand -hex 12)

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
sign_jwt() { # $1 = role
  local now exp h p s
  now=$(date +%s); exp=$((now + 315360000)) # 10 年
  h=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  p=$(printf '{"role":"%s","iss":"supabase","iat":%s,"exp":%s}' "$1" "$now" "$exp" | b64url)
  s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
  printf '%s.%s.%s' "$h" "$p" "$s"
}
ANON_KEY=$(sign_jwt anon)
SERVICE_KEY=$(sign_jwt service_role)

set_env() { # KEY VALUE(存在则替换,不存在则追加)
  if grep -q "^$1=" .env; then
    sed -i "s|^$1=.*|$1=$2|" .env
  else
    echo "$1=$2" >> .env
  fi
}
set_env POSTGRES_PASSWORD "$PG_PASS"
set_env JWT_SECRET "$JWT_SECRET"
set_env ANON_KEY "$ANON_KEY"
set_env SERVICE_ROLE_KEY "$SERVICE_KEY"
set_env SITE_URL "https://$DOMAIN"
set_env API_EXTERNAL_URL "https://$DOMAIN"
set_env SUPABASE_PUBLIC_URL "https://$DOMAIN"
set_env DASHBOARD_USERNAME admin
set_env DASHBOARD_PASSWORD "$DASH_PASS"
set_env SMTP_HOST "$SMTP_HOST"
set_env SMTP_PORT "$SMTP_PORT"
set_env SMTP_USER "$SMTP_USER"
set_env SMTP_PASS "$SMTP_PASS"
set_env SMTP_ADMIN_EMAIL "$SMTP_FROM"
set_env SMTP_SENDER_NAME "PureThoughts"
set_env ENABLE_EMAIL_AUTOCONFIRM false

# ---------------------------------------------------------------- 本项目:函数 + SQL
echo "==> 拉取应用仓库(migration / Edge Functions)"
rm -rf /tmp/app && git clone --depth 1 -q "$APP_REPO" /tmp/app
mkdir -p volumes/functions
cp -r /tmp/app/supabase/functions/* volumes/functions/

echo "==> 启动 Supabase(首次拉镜像需几分钟)"
sudo docker compose pull -q
sudo docker compose up -d
echo "    等待数据库就绪..."
until sudo docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; do sleep 3; done
sleep 10

echo "==> 应用 migration(带追踪,可重复执行)"
sudo docker exec supabase-db psql -U postgres -q -c \
  "create table if not exists public._applied_migrations (name text primary key, at timestamptz default now());"
for f in /tmp/app/supabase/migrations/*.sql; do
  name=$(basename "$f")
  done_already=$(sudo docker exec supabase-db psql -U postgres -tA -c \
    "select 1 from public._applied_migrations where name='$name'")
  if [ "$done_already" != "1" ]; then
    echo "    applying $name"
    sudo docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 -q < "$f"
    sudo docker exec supabase-db psql -U postgres -q -c \
      "insert into public._applied_migrations (name) values ('$name')"
  fi
done

echo "==> 生产内容种子(功课清单/经本;不含测试账号)"
sudo docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 -q <<'SQL'
insert into public.practice_types (name_hant, name_hans, category, unit, is_custom, sort_order)
select * from (values
  ('金剛經','金刚经','sutra'::public.practice_category,'volume'::public.practice_unit,false,10),
  ('地藏經','地藏经','sutra','volume',false,11),
  ('藥師經','药师经','sutra','volume',false,12),
  ('阿彌陀經','阿弥陀经','sutra','volume',false,13),
  ('無量壽經','无量寿经','sutra','volume',false,14),
  ('心經','心经','sutra','volume',false,15),
  ('大悲咒','大悲咒','mantra','recitation',false,20),
  ('楞嚴咒','楞严咒','mantra','recitation',false,21),
  ('十小咒','十小咒','mantra','recitation',false,22),
  ('往生咒','往生咒','mantra','recitation',false,23),
  ('準提咒','准提咒','mantra','recitation',false,24),
  ('地藏懺','地藏忏','repentance','recitation',false,30),
  ('八十八佛大懺悔文','八十八佛大忏悔文','repentance','recitation',false,31),
  ('梁皇寶懺','梁皇宝忏','repentance','recitation',false,32),
  ('念佛','念佛','buddha_name','count',false,40),
  ('觀音聖號','观音圣号','buddha_name','count',false,41),
  ('靜坐','静坐','meditation','minute',false,50)
) v(a,b,c,d,e,f)
where not exists (select 1 from public.practice_types where group_id is null);
insert into public.scriptures (title, web_url, sort_order)
select '乾隆大藏經','https://qldazangjing.com/',1
where not exists (select 1 from public.scriptures);
SQL

echo "==> pg_cron:开播探测(每 5 分钟)"
sudo docker exec -i supabase-db psql -U postgres -v ON_ERROR_STOP=1 -q <<SQL
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.unschedule('live-probe-5min') where exists
  (select 1 from cron.job where jobname = 'live-probe-5min');
select cron.schedule('live-probe-5min', '*/5 * * * *', \$\$
  select net.http_post(
    url := 'http://kong:8000/functions/v1/live-probe',
    headers := '{"Authorization": "Bearer $ANON_KEY", "apikey": "$ANON_KEY", "Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb);
\$\$);
SQL

# ---------------------------------------------------------------- HTTPS
echo "==> 配置 Caddy(自动 HTTPS)"
sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$DOMAIN {
    reverse_proxy localhost:8000
}
EOF
sudo systemctl restart caddy

# ---------------------------------------------------------------- 备份
echo "==> 安装每日备份(03:00)"
mkdir -p "$HOME/backups"
sudo tee /usr/local/bin/pt-backup.sh >/dev/null <<EOF
#!/bin/bash
set -e
F=\$HOME/backups/pt-\$(date +%F).sql.gz
docker exec supabase-db pg_dumpall -U postgres | gzip > \$F
$( [ -n "$S3_BUCKET" ] && echo "aws s3 cp \$F s3://$S3_BUCKET/db/ && rm \$F" || echo "ls -t \$HOME/backups/*.gz | tail -n +15 | xargs -r rm" )
EOF
sudo chmod +x /usr/local/bin/pt-backup.sh
(crontab -l 2>/dev/null | grep -v pt-backup; echo "0 3 * * * /usr/local/bin/pt-backup.sh") | crontab -
[ -n "$S3_BUCKET" ] && sudo apt-get install -y -qq awscli >/dev/null || true

# ---------------------------------------------------------------- 完成
CREDS="$HOME/purethoughts-credentials.txt"
cat > "$CREDS" <<EOF
=========== 善护念 生产环境凭据(立即存入密码管理器,然后删除本文件)===========
API URL:            https://$DOMAIN
ANON_KEY:           $ANON_KEY
SERVICE_ROLE_KEY:   $SERVICE_KEY
JWT_SECRET:         $JWT_SECRET
POSTGRES_PASSWORD:  $PG_PASS
Studio 管理台:      https://$DOMAIN  (用户 admin / 密码 $DASH_PASS)
EOF
chmod 600 "$CREDS"

echo ""
echo "=============================================="
echo " ✅ 部署完成"
echo "=============================================="
echo " 凭据已写入 $CREDS(读完请删除)"
echo ""
echo " 验证:  curl https://$DOMAIN/auth/v1/health"
echo ""
echo " 剩余 3 步(见 docs/infra/deploy-aws-ec2.md):"
echo "  1. Codemagic production 环境组填 SUPABASE_URL / ANON_KEY"
echo "  2. App 注册第一个账号后设为管理员:"
echo "     sudo docker exec supabase-db psql -U postgres -c \\"
echo "       \"update public.profiles set is_app_admin=true where id=(select id from auth.users where email='你的邮箱')\""
echo "  3. 一次备份恢复演练(上线硬门槛)"
