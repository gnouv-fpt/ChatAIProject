#!/usr/bin/env bash
# Chuan bi moi truong local cho REST API service: user-secrets + build.
# Chay 1 lan sau khi pull/clone repo:
#   bash scripts/setup.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
presentation="$root/Presentation"

echo "==> Kiem tra .NET SDK"
dotnet --version > /dev/null

echo "==> Restore packages"
dotnet restore "$root/ChatAIWeb.slnx"

secret_exists() {
  dotnet user-secrets list --project "$presentation" 2>/dev/null | grep -q "^$1 = "
}

echo "==> Cau hinh user-secrets (Jwt:SecretKey, tai khoan admin mac dinh)"

if ! secret_exists "Jwt:SecretKey"; then
  random_key=$(openssl rand -base64 48)
  dotnet user-secrets set "Jwt:SecretKey" "$random_key" --project "$presentation" > /dev/null
  echo "   - Da tao Jwt:SecretKey ngau nhien cho may nay."
else
  echo "   - Jwt:SecretKey da ton tai, giu nguyen."
fi

if ! secret_exists "Auth:SeedAdmin:Email"; then
  dotnet user-secrets set "Auth:SeedAdmin:Email" "admin@chataiweb.local" --project "$presentation" > /dev/null
  dotnet user-secrets set "Auth:SeedAdmin:Password" "Admin@123456" --project "$presentation" > /dev/null
  echo "   - Tai khoan admin mac dinh: admin@chataiweb.local / Admin@123456"
else
  echo "   - Auth:SeedAdmin da cau hinh, giu nguyen."
fi

echo "==> Build solution"
dotnet build "$root/ChatAIWeb.slnx"

cat <<'EOF'

Xong! Chua apply migrations. Xem docs/C2-SCHEMA-CONTRACT.md cho hai SQL DB.
Chay API:
  dotnet run --project Presentation --launch-profile http
Swagger: http://localhost:5039/swagger

Cau hinh UserConnection va ContentConnection; chay them profile content tren port 5040.
Sau khi apply schema, co the seed admin bang --Auth:SeedAdminOnStartup true tren User host.
(mac dinh dung SQL Server local, Windows Authentication).
EOF
