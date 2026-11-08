#!/usr/bin/env bash
# 用法：bash i.sh [-y]；安装无需密钥，备份仍独立加密。
set -euo pipefail
umask 077
RAW="https://raw.githubusercontent.com/vvangpc/mmffgic/main"
[[ $EUID -eq 0 ]] || { echo "请用 root 运行（先执行 sudo -i）"; exit 1; }
for arg in "$@"; do
  [[ $arg == -y ]] || { echo "用法：bash i.sh [-y]；恢复请安装后执行 sb backup restore"; exit 2; }
done
for c in curl openssl tar; do
  command -v "$c" >/dev/null || { apt-get update -qq && apt-get install -y -qq curl openssl tar >/dev/null; break; }
done
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
cat >"$T/release.pub" <<'PUBLIC_KEY'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEANdF+GQ/cgARLrKngq4oqRlDSJ3UiRDQ9wRpoEMYQ1d8=
-----END PUBLIC KEY-----
PUBLIC_KEY
#!/usr/bin/env bash
# Ed25519 signature binds the payload and version to the maintainer key.
release_verify() {
  local dir=$1 pub=$2 version=$3 sha declared
  [[ -s $dir/manifest && -s $dir/manifest.sig && -s $pub ]] || return 1
  openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$dir/manifest" -sigfile "$dir/manifest.sig" >/dev/null 2>&1 || return 1
  [[ $(wc -l <"$dir/manifest") == 2 ]] || return 1
  declared=$(sed -n '1p' "$dir/manifest"); sha=$(sed -n '2p' "$dir/manifest")
  [[ $declared == "$version" && $declared =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $sha =~ ^[a-f0-9]{64}$ ]] || return 1
  [[ $(sha256sum "$dir/p.tgz" | cut -d' ' -f1) == "$sha" ]]
}
echo "[*] 下载并验证安装包..."
for asset in manifest manifest.sig v p.tgz; do
  curl -4 -fsSL --retry 3 --max-time 120 -o "$T/$asset" "$RAW/$asset" || { echo "下载失败，请稍后重试"; exit 1; }
done
VERSION=$(tr -d '[:space:]' <"$T/v")
release_verify "$T" "$T/release.pub" "$VERSION" || { echo "发布签名或文件校验失败，未安装"; exit 1; }
tar -xzf "$T/p.tgz" -C "$T" || { echo "安装包无法解包"; exit 1; }
[[ $(tr -d '[:space:]' <"$T/installer/VERSION") == "$VERSION" ]] || { echo "包内版本不匹配"; exit 1; }
echo "[✓] 安装包版本 $VERSION（签名通过）"
# Existing installations use the transactional updater without regenerating parameters.
if [[ -L /usr/local/bin/sb && -f $(readlink -f /usr/local/bin/sb) ]]; then
  (
  # Existing libraries use explicit return checks, not nounset/errexit.
  set +eu
  export SB_HOME; SB_HOME=$(dirname "$(readlink -f /usr/local/bin/sb)")
  source "$SB_HOME/lib/load.sh"
  release_verify "$T" "$SB_HOME/lib/release.pub" "$VERSION" || { echo "与已安装公钥不匹配"; exit 1; }
  source "$T/installer/lib/self.sh"
  self_repo() { printf '%s\n' "$RAW"; }
  with_lock self_update "" "$T/installer/lib/release-verify.sh"
  )
else
  bash "$T/installer/install.sh" --repo "$RAW" "$@"
fi
