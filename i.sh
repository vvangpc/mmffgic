#!/usr/bin/env bash
# 用法：bash <(curl -Ls https://raw.githubusercontent.com/vvangpc/mmffgic/main/i.sh) <密钥> [-y] [--restore 备份文件]
set -euo pipefail
umask 077
RAW="https://raw.githubusercontent.com/vvangpc/mmffgic/main"
KEY=${1:-}
[[ -n $KEY ]] || { echo "用法：bash <(curl -Ls $RAW/i.sh) <密钥>"; exit 1; }
shift
[[ $EUID -eq 0 ]] || { echo "请用 root 运行（先执行 sudo -i）"; exit 1; }
for c in curl openssl tar; do
  command -v $c >/dev/null || { apt-get update -qq && apt-get install -y -qq curl openssl tar >/dev/null; break; }
done
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cat >"$T/release.pub" <<'PUBLIC_KEY'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEANdF+GQ/cgARLrKngq4oqRlDSJ3UiRDQ9wRpoEMYQ1d8=
-----END PUBLIC KEY-----
PUBLIC_KEY
#!/usr/bin/env bash
# Ed25519 signature binds the encrypted payload and version to the maintainer key.
release_verify() {
  local dir=$1 pub=$2 version=$3 sha declared
  [[ -s $dir/manifest && -s $dir/manifest.sig && -s $pub ]] || return 1
  openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$dir/manifest" -sigfile "$dir/manifest.sig" >/dev/null 2>&1 || return 1
  [[ $(wc -l <"$dir/manifest") == 2 ]] || return 1
  declared=$(sed -n '1p' "$dir/manifest"); sha=$(sed -n '2p' "$dir/manifest")
  [[ $declared == "$version" && $declared =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $sha =~ ^[a-f0-9]{64}$ ]] || return 1
  [[ $(sha256sum "$dir/p.bin" | cut -d' ' -f1) == "$sha" ]]
}
echo "[*] 下载安装包..."
curl -4 -fsSL --retry 3 -o "$T/p.bin" "$RAW/p.bin?t=$(date +%s)" || { echo "[✗] 下载失败，请检查网络"; exit 1; }
for asset in manifest manifest.sig v; do curl -4 -fsSL --max-time 120 -o "$T/$asset" "$RAW/$asset"; done
release_verify "$T" "$T/release.pub" "$(tr -d '[:space:]' <"$T/v")" || { echo "发布签名校验失败"; exit 1; }
printf '%s' "$KEY" >"$T/install.key"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -in "$T/p.bin" -out "$T/p.tgz" -pass "file:$T/install.key" 2>/dev/null &&
  tar -xzf "$T/p.tgz" -C "$T" 2>/dev/null || { echo "[✗] 解密失败：密钥不对"; exit 1; }
echo "[✓] 安装包版本 $(cat "$T/installer/VERSION")"
bash "$T/installer/install.sh" --key "$KEY" --repo "$RAW" "$@"
