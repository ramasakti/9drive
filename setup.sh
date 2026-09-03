#!/usr/bin/env sh
set -eu

if ! command -v bun >/dev/null 2>&1; then
  echo "Bun is required." >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
backend_dir="$script_dir/backend"
frontend_dir="$script_dir/frontend"

random_key() {
  bun -e "console.log(Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString('hex'))"
}

if [ ! -f "$backend_dir/.env" ]; then
  printf "MySQL DATABASE_URL [mysql://root@localhost:3306/9drive]: "
  IFS= read -r database_url
  database_url=${database_url:-mysql://root@localhost:3306/9drive}

  {
    printf 'DATABASE_URL="%s"\n' "$database_url"
    printf 'APP_PORT=4000\n'
    printf 'FRONTEND_URL="http://localhost:5173"\n'
    printf 'JWT_ACCESS_SECRET="%s"\n' "$(random_key)"
    printf 'TOKEN_ENCRYPTION_KEY="%s"\n' "$(random_key)"
    printf 'ACCESS_TOKEN_TTL_SECONDS=900\n'
    printf 'REFRESH_TOKEN_TTL_DAYS=30\n'
    printf 'MAX_UPLOAD_BYTES=5368709120\n'
    printf 'RECAPTCHA_SECRET_KEY=""\n'
    printf 'GOOGLE_CLIENT_ID=""\n'
    printf 'GOOGLE_CLIENT_SECRET=""\n'
    printf 'GOOGLE_REDIRECT_URI="http://localhost:4000/connected-accounts/google/callback"\n'
  } > "$backend_dir/.env"
  echo "Created backend/.env"
fi

if [ ! -f "$frontend_dir/.env" ]; then
  {
    printf 'VITE_API_URL=http://localhost:4000\n'
    printf 'VITE_RECAPTCHA_SITE_KEY=\n'
  } > "$frontend_dir/.env"
  echo "Created frontend/.env"
fi

(cd "$backend_dir" && bun install && bun run prisma:generate)
(cd "$frontend_dir" && bun install)

echo "Setup complete. Run migrations with: cd backend && bun run prisma:migrate"
