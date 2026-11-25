#!/usr/bin/env bash
set -euo pipefail

fingerprint() { openssl pkey -pubin -in "$1" -pubout -outform DER | sha256sum | cut -d' ' -f1; }
rotate_key() (
  local home=$1 action=$2 old new key backup stage current version
  old=9324e93b19b8e1459a63beabe64310faa0660851d7a98e1d6c9a7cb399970950
  new=c65e3487209c36490d6a593f447c652f12d9f70f6f1de073885d80fe23a53ab1
  key=$home/lib/release.pub
  backup=$home/etc/release-before-0.5.12.pub
  [[ -f $key && ! -L $key && -d $home/etc && ! -L $home/etc && ! -L $home/lib ]] || exit 1
  current=$(fingerprint "$key")
  if [[ $current != "$old" && $current != "$new" ]]; then echo '本机公钥指纹未知，已停止。' >&2; exit 1; fi
  if [[ -e $backup || -L $backup ]]; then
    [[ -f $backup && ! -L $backup && $(fingerprint "$backup") == "$old" ]] || { echo '旧公钥备份无效。' >&2; exit 1; }
  fi
  case $action in
    apply)
      if [[ $current == "$new" ]]; then echo '本机已经信任新公钥。'; exit 0; fi
      if [[ ! -e $backup ]]; then
        stage=$(mktemp "$home/etc/.release-backup.XXXXXXXX"); trap 'rm -f -- "$stage"' EXIT
        cp -- "$key" "$stage"; cmp -- "$key" "$stage"; mv -T -- "$stage" "$backup"
      fi
      stage=$(mktemp "$home/lib/.release-key.XXXXXXXX"); trap 'rm -f -- "$stage"' EXIT
      cat >"$stage" <<'PEM'
-----BEGIN PUBLIC KEY-----
MCowBQYDK2VwAyEAUqys6H2To6Aa6UJ1pK5xoVigvSop30/aoYvQs2AklGs=
-----END PUBLIC KEY-----
PEM
      [[ $(fingerprint "$stage") == "$new" ]] || exit 1
      ;;
    restore)
      version=$(cat "$home/VERSION")
      [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && $version != 0.5.12 && $(printf '%s\n' "$version" 0.5.12 | sort -V | head -1) == "$version" ]] || { echo '只可在升级到 0.5.12 之前撤销迁移。' >&2; exit 1; }
      if [[ $current == "$old" ]]; then echo '当前即为旧公钥。'; exit 0; fi
      [[ -f $backup ]] || { echo '缺少旧公钥备份。' >&2; exit 1; }
      stage=$(mktemp "$home/lib/.release-key.XXXXXXXX"); trap 'rm -f -- "$stage"' EXIT
      cp -- "$backup" "$stage"; [[ $(fingerprint "$stage") == "$old" ]] || exit 1
      ;;
    *) echo '用法：bash migrate-key.sh apply|restore' >&2; exit 2 ;;
  esac
  chmod --reference="$key" "$stage"; mv -T -- "$stage" "$key"
  echo "当前发布公钥指纹：$(fingerprint "$key")"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  [[ $# == 1 && $EUID == 0 ]] || { echo '请在目标 VPS 的 root 终端执行，并指定 apply 或 restore。' >&2; exit 2; }
  umask 077
  exec 8>/run/vps-magic-deploy.lock; flock -n 8 || { echo '有面板操作正在进行，请稍后重试。' >&2; exit 1; }
  link=/usr/local/bin/sb
  [[ -L $link ]] || { echo '未找到 sb 安装链接。' >&2; exit 1; }
  target=$(readlink -e "$link")
  [[ $target =~ ^/opt/([a-z]{6})/sb\.sh$ ]] || { echo '安装路径与预期不符。' >&2; exit 1; }
  exec 9>"/run/${BASH_REMATCH[1]}.lock"; flock -n 9 || { echo '有节点操作正在进行，请稍后重试。' >&2; exit 1; }
  rotate_key "${target%/*}" "$1"
fi
