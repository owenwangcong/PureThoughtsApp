#!/bin/bash
# ============================================================================
# 善护念 PureThoughts · 自托管 Supabase 一键部署
#
# 两种模式:
#   1 = 独立服务器(Ubuntu 24.04 全新 EC2):自动装 Caddy,HTTPS 全自动
#   2 = 共置已有 Apache 服务器(如 Bitnami):跳过 Caddy,Kong 改端口 8010,
#       证书用 certbot、vhost 手动配(步骤见 docs/infra/deploy-aws-ec2.md 附录方案 A)
#
# 前提:1) 域名 A 记录已指向本机公网 IP  2) 独立模式:安全组只开 22/80/443
# 用法:ssh 到服务器后执行
#   curl -fsSL https://raw.githubusercontent.com/owenwangcong/PureThoughtsApp/master/scripts/deploy/setup-supabase-ec2.sh -o setup.sh
#   bash setup.sh
# 全程约 5-10 分钟。
#
# 自动完成:Docker + Supabase(官方 compose)+ 密钥生成(含 JWT 签名)
#   + HTTPS(模式 1)+ 本项目全部 migration + Edge Functions
#   + pg_cron 开播探测 + 生产内容种子 + 每日备份
# ============================================================================
set -euo pipefail

APP_REPO="https://github.com/owenwangcong/PureThoughtsApp.git"
DIR="$HOME/purethoughts"

echo "=============================================="
echo " 善护念 Supabase 一键部署"
echo "=============================================="
# 交互提示:重复执行时直接回车即保留 .env 现值(避免复跑清空配置)
prompt_keep() { # $1=变量名 $2=.env 键名 $3=提示语 $4=是否密文(1=是)
  local old="" input
  [ -f "$DIR/.env" ] && old=$(grep "^$2=" "$DIR/.env" | head -1 | cut -d= -f2-)
  if [ "$4" = "1" ]; then
    read -rsp "$3${old:+ [回车保留现值]}: " input; echo
  else
    read -rp "$3${old:+ [回车保留 $old]}: " input
  fi
  printf -v "$1" '%s' "${input:-$old}"
}

read -rp "部署模式 [1=独立服务器(Caddy 自动 HTTPS) 2=共置已有 Apache(Bitnami)] [1]: " MODE
MODE=${MODE:-1}
prompt_keep DOMAIN SITE_URL "API 域名(A 记录须已指向本机,如 api.pure-thoughts.com)" 0
DOMAIN=${DOMAIN#https://}; DOMAIN=${DOMAIN#http://}; DOMAIN=${DOMAIN%%/*}
prompt_keep SMTP_HOST SMTP_HOST "SMTP 主机(如 smtp.resend.com)" 0
prompt_keep SMTP_PORT SMTP_PORT "SMTP 端口 [587]" 0; SMTP_PORT=${SMTP_PORT:-587}
prompt_keep SMTP_USER SMTP_USER "SMTP 用户名(Resend 填 resend)" 0
prompt_keep SMTP_PASS SMTP_PASS "SMTP 密码/API Key" 1
prompt_keep SMTP_FROM SMTP_ADMIN_EMAIL "发件邮箱(如 no-reply@pure-thoughts.com)" 0
read -rp "S3 备份桶名(留空则仅备份到本机 ~/backups): " S3_BUCKET

# ---------------------------------------------------------------- 共置模式预检
if [ "$MODE" = "2" ]; then
  echo "==> 共置模式预检(内存 / 端口)"
  AVAIL_MB=$(awk '/MemAvailable/ {print int($2/1024)}' /proc/meminfo)
  if [ "$AVAIL_MB" -lt 3000 ]; then
    echo "❌ 可用内存仅 ${AVAIL_MB}MB(< 3GB)。共置 Supabase 会把主站一起拖垮,请先升配或改用独立服务器。"
    exit 1
  fi
  for p in 8010 8453 4000 5432 6543; do
    if ss -ltn "sport = :$p" 2>/dev/null | grep -q LISTEN; then
      echo "❌ 端口 $p 已被占用(ss -ltn 查看)。请释放或改 .env 后重跑。"
      exit 1
    fi
  done
  echo "    可用内存 ${AVAIL_MB}MB,端口 8010/8453/4000/5432/6543 空闲 ✓"
fi

# ---------------------------------------------------------------- 依赖
if ! command -v docker >/dev/null; then
  echo "==> 安装 Docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi
sudo apt-get update -qq
if [ "$MODE" = "1" ]; then
  sudo apt-get install -y -qq caddy git openssl >/dev/null
else
  sudo apt-get install -y -qq git openssl >/dev/null
fi

# ---------------------------------------------------------------- 取官方 compose
echo "==> 下载 Supabase 官方 Docker 配置"
rm -rf /tmp/sb && git clone --depth 1 -q https://github.com/supabase/supabase /tmp/sb
# 注意用 /. 结尾:带上 .env.example 等隐藏文件(* 通配符不匹配点文件)
mkdir -p "$DIR" && cp -rn /tmp/sb/docker/. "$DIR"/ && cd "$DIR"
[ -f .env ] || cp .env.example .env

# ---------------------------------------------------------------- 生成密钥
set_env() { # KEY VALUE(存在则替换,不存在则追加)
  if grep -q "^$1=" .env; then
    sed -i "s|^$1=.*|$1=$2|" .env
  else
    echo "$1=$2" >> .env
  fi
}
get_env() { grep "^$1=" .env | head -1 | cut -d= -f2-; }

# 密钥只生成一次:.env 里还是演示值才生成;已是真实密钥则跳过(保证脚本可重复执行——
# 重复生成会换掉 POSTGRES_PASSWORD,与已初始化的数据库卷对不上,整套服务连不上库)
CUR_JWT=$(get_env JWT_SECRET)
if [ -n "$CUR_JWT" ] && [[ "$CUR_JWT" != your-super-secret* ]]; then
  echo "==> 密钥已存在,跳过生成(重复执行)"
elif [ -d volumes/db/data ] && [ -n "$(ls -A volumes/db/data 2>/dev/null)" ]; then
  echo "❌ 数据库卷已初始化,但 .env 还是演示密钥(多半是之前手动 up 过)。"
  echo "   请先彻底清理再重跑:"
  echo "   cd $DIR && sudo docker compose down -v && cd ~ && rm -rf $DIR"
  exit 1
elif [ -f utils/generate-keys.sh ]; then
  # 新版官方结构(2026):一条命令生成全部密钥(JWT/加密键/DB 与管理台密码)写入 .env
  echo "==> 生成密钥(官方 utils/generate-keys.sh)"
  bash utils/generate-keys.sh --update-env >/dev/null
else
  # 旧版结构:自签 HS256 JWT
  echo "==> 生成密钥与 JWT(自签)"
  JWT_SECRET=$(openssl rand -hex 32)
  b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
  sign_jwt() { # $1 = role
    local now exp h p s
    now=$(date +%s); exp=$((now + 315360000)) # 10 年
    h=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
    p=$(printf '{"role":"%s","iss":"supabase","iat":%s,"exp":%s}' "$1" "$now" "$exp" | b64url)
    s=$(printf '%s.%s' "$h" "$p" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
    printf '%s.%s.%s' "$h" "$p" "$s"
  }
  set_env JWT_SECRET "$JWT_SECRET"
  set_env ANON_KEY "$(sign_jwt anon)"
  set_env SERVICE_ROLE_KEY "$(sign_jwt service_role)"
  set_env POSTGRES_PASSWORD "$(openssl rand -hex 16)"
  set_env DASHBOARD_PASSWORD "$(openssl rand -hex 12)"
fi
JWT_SECRET=$(get_env JWT_SECRET)
ANON_KEY=$(get_env ANON_KEY)
SERVICE_KEY=$(get_env SERVICE_ROLE_KEY)
PG_PASS=$(get_env POSTGRES_PASSWORD)
DASH_PASS=$(get_env DASHBOARD_PASSWORD)

# 站点 URL:保留上游默认值的路径结构,只替换协议+主机(新版 API_EXTERNAL_URL 可能带 /auth/v1 路径)
for k in SITE_URL API_EXTERNAL_URL SUPABASE_PUBLIC_URL; do
  cur=$(get_env "$k")
  if [ -n "$cur" ]; then
    set_env "$k" "$(echo "$cur" | sed -E "s|https?://[^/]+|https://$DOMAIN|")"
  else
    set_env "$k" "https://$DOMAIN"
  fi
done
set_env DASHBOARD_USERNAME admin
set_env SMTP_HOST "$SMTP_HOST"
set_env SMTP_PORT "$SMTP_PORT"
set_env SMTP_USER "$SMTP_USER"
set_env SMTP_PASS "$SMTP_PASS"
set_env SMTP_ADMIN_EMAIL "$SMTP_FROM"
set_env SMTP_SENDER_NAME "PureThoughts"
# PRD v0.5.9:账号体系 = 用户名+密码,注册免邮箱验证(邮箱选填仅作找回)
set_env ENABLE_EMAIL_AUTOCONFIRM true
if [ "$MODE" = "2" ]; then
  # 共置:避开 FastAPI 的 8000 与 Bitnami Apache 的 8443
  set_env KONG_HTTP_PORT 8010
  set_env KONG_HTTPS_PORT 8453
fi

# ---------------------------------------------------------------- 本项目:函数 + SQL
echo "==> 获取应用仓库(migration / Edge Functions)"
if [ -d "$HOME/PureThoughtsApp/supabase/migrations" ]; then
  # 私有仓库场景:用户已从本机 scp 上来的副本优先,无需 GitHub 凭据
  echo "    使用本地副本 ~/PureThoughtsApp"
  rm -rf /tmp/app && cp -r "$HOME/PureThoughtsApp" /tmp/app
else
  rm -rf /tmp/app && git clone --depth 1 -q "$APP_REPO" /tmp/app
fi
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

echo "==> 重载 Edge Functions(复跑时使函数代码更新生效)"
sudo docker compose restart functions >/dev/null

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
if [ "$MODE" = "1" ]; then
  echo "==> 配置 Caddy(自动 HTTPS)"
  sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$DOMAIN {
    reverse_proxy localhost:8000
}
EOF
  sudo systemctl restart caddy
else
  echo "==> 共置模式:跳过 Caddy。请按文档附录方案 A 配置 certbot 证书 + Apache vhost(反代 127.0.0.1:8010)"
fi

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
if [ "$MODE" = "2" ]; then
  echo " ⚠️ 共置模式:Supabase 已在 127.0.0.1:8010 运行,但还没有对外入口。"
  echo "    请按 docs/infra/deploy-aws-ec2.md 附录方案 A 完成:"
  echo "    certbot 签发 $DOMAIN 证书 → Apache 加 80/443 vhost → 重启 Apache"
  echo ""
fi
echo " 验证:  curl https://$DOMAIN/auth/v1/health"
echo ""
echo " 剩余 3 步(见 docs/infra/deploy-aws-ec2.md):"
echo "  1. Codemagic production 环境组填 SUPABASE_URL / ANON_KEY"
echo "  2. App 注册第一个账号后设为管理员:"
echo "     sudo docker exec supabase-db psql -U postgres -c \\"
echo "       \"update public.profiles set is_app_admin=true where id=(select id from auth.users where email='你的邮箱')\""
echo "  3. 一次备份恢复演练(上线硬门槛)"
