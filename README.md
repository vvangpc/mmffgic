# mmffgic 安装包与维护入口

本仓库的 `main` 提供 VPS 使用的五个已签名发布文件。按版本留存的同一组文件可以在 [Releases](https://github.com/vvangpc/mmffgic/releases) 下载。

**已安装的 VPS 首次升级到 0.5.12 或以后版本**，请先在目标机器上手动完成[公钥迁移](migrations/0.5.12.md)，再点击面板的脚本更新。电脑、手机和路由器沿用原订阅地址。

## 换电脑继续开发

日常改脚本请打开[私有源码仓库](https://github.com/vvangpc/mmffgic-src)。在有访问权限的电脑上，首次克隆一次：

```sh
gh repo clone vvangpc/mmffgic-src
```

以后在源码目录正常 `git pull`、修改、提交和推送。发布新版时，把 `installer/VERSION` 与脚本改动一起推送到私有仓库 `main`。GitHub Actions 自动打包、签名、验证旧版升级和回滚，然后推送到本仓库并创建 Release。维护电脑只需已有的 GitHub 写入权限。已发布的文件在本公开仓库执行 `git pull --ff-only` 即可取得。

网页面板单独部署。某台 VPS 何时升级，由该机的更新设置及操作者决定。

## 家庭路由器

家里的电脑拉取本仓库后，运行 `sh router/check-openclash.sh` 盘点 GL-MT3600BE，再让家庭 AI 按[OpenClash 交接报告](router/OPENCLASH-HANDOFF.md)适配和验收。脚本只读，真实订阅地址保存在家庭设备上。
