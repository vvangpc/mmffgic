# mmffgic 安装包与维护入口

本仓库的 `main` 分支提供 VPS 安装和升级使用的签名包。开发源码、面板网页、构建脚本和测试位于私有仓库 [vvangpc/mmffgic-src](https://github.com/vvangpc/mmffgic-src)。

## 换电脑继续开发

克隆或更新本仓库后，在本仓库根目录执行以下命令，将源码下载到同级的 `mmffgic-src` 目录。使用有权访问私有仓库的 GitHub 账号；首次使用 GitHub CLI 时，先运行 `gh auth login`。

```sh
gh repo clone vvangpc/mmffgic-src ../mmffgic-src
```

如果同级目录已经有源码，使用：

```sh
git -C ../mmffgic-src pull --ff-only
```

面板与 VPS 安装包分别发布。进入私有源码目录后，按其 README 执行相应的测试和发布步骤。打包前，将 `build/release.conf` 的 `DIR` 指向本机的公开仓库工作目录。从维护者的安全备份恢复原发布私钥到 `build/.signing-key`，或使用 `PACK_SIGNING_KEY` 指向原私钥文件。
