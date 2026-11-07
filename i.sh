#!/usr/bin/env bash
# 用法：bash <(curl -Ls https://raw.githubusercontent.com/vvangpc/mmffgic/main/i.sh) <密钥> [-y] [--restore 备份文件]
set -o pipefail
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
echo "[*] 下载安装包..."
curl -4 -fsSL --retry 3 -o "$T/p.bin" "$RAW/p.bin?t=$(date +%s)" || { echo "[✗] 下载失败，请检查网络"; exit 1; }
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -in "$T/p.bin" -out "$T/p.tgz" -pass "pass:$KEY" 2>/dev/null &&
  tar -xzf "$T/p.tgz" -C "$T" 2>/dev/null || { echo "[✗] 解密失败：密钥不对"; exit 1; }
echo "[✓] 安装包版本 $(cat "$T/installer/VERSION")"
bash "$T/installer/install.sh" --key "$KEY" --repo "$RAW" "$@"
