# DeepSeek Harness 手机客户端(iOS)— 打包与自签安装指南

> **先说清楚原理(重要,避免误解)**
>
> DeepSeek Harness 的核心(agent 引擎、文件读写、PowerShell、模型调用)全部运行在你的 **Windows 电脑**上,iPhone 上无法、也不可能运行这些组件(需要 macOS + Xcode 才能编译 iOS 程序,而且 iOS 系统沙盒不允许执行这些功能)。
>
> 所以这个 IPA 是一个**远程客户端**:手机上显示完整的操作界面,实际干活的是电脑。**使用时电脑必须开机并运行 Harness。**

---

## 这个包里有什么

```
dsh-ios-ipa/
├─ HarnessClient.xcodeproj/        # Xcode 工程(可直接在 Mac 上打开构建)
├─ HarnessClient/                  # Swift 源码(WKWebView 客户端外壳)
│  ├─ App.swift
│  ├─ BrowserViewController.swift  # 主界面:连接页 / 网页 / 工具栏
│  ├─ Info.plist
│  └─ Assets.xcassets/             # 应用图标
├─ .github/workflows/build-ipa.yml # GitHub Actions 云端构建脚本(关键)
├─ pc-bridge.mjs                   # 电脑端桥接脚本(让手机能访问电脑)
├─ start-bridge.ps1                # 桥接一键启动器(Windows)
└─ README.md                       # 本文档
```

产出物:**未签名 IPA**(`DeepSeekHarnessClient-unsigned.ipa`),兼容 iOS 16.0 及以上(你的 16.3.1 满足),之后用你的自签软件签名安装。

---

## 第一步:电脑端 — 启动桥接(让手机能连上)

Harness 的界面默认只监听 `127.0.0.1`(仅本机),手机连不上,所以需要一个桥接把它转发到局域网。

**免管理员方式(推荐):**

1. 双击 `start-bridge.ps1`(或右键 →"使用 PowerShell 运行")。
   它会用 Node 运行 `pc-bridge.mjs`,把 `0.0.0.0:19390` 转发到 `127.0.0.1:19387`。
2. **首次运行时 Windows 防火墙会弹窗,务必勾选"专用网络"并点"允许访问"**(没弹或点错了也没关系,见文末排查)。
3. 保持这个窗口开着(关掉窗口 = 桥接停止)。

> 没装 Node 也没关系:`start-bridge.ps1` 会自动使用 DeepSeek Harness 自带的 Node;
> 也可以自行安装 [Node.js 18+](https://nodejs.org) 后运行 `node pc-bridge.mjs`。

**管理员方式(二选一,已装桥接脚本就跳过):**

以管理员身份打开 PowerShell,执行(注意监听端口用 **19390**,避开已被占用的 19387):

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=19390 connectaddress=127.0.0.1 connectport=19387
New-NetFirewallRule -DisplayName "DSH Bridge 19390" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 19390
```

想撤销时:

```powershell
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=19390
```

**自测:** 手机浏览器打开 `http://192.168.2.92:19390`(电脑 Wi-Fi IP,以 `ipconfig` 实际为准)。能看到 Harness 界面,说明第一步成功。

---

## 第二步:GitHub 云端构建 IPA(一次约 3~5 分钟)

编译 iOS 程序必须用 macOS,所以借助 GitHub 免费提供的 macOS 云电脑:

1. 注册/登录 [github.com](https://github.com)(免费)。
2. 右上角 **+** → **New repository** → 起名如 `dsh-ios-client`,可选 **Private**,点 **Create**。
3. 把 `dsh-ios-ipa` 文件夹里的**全部内容**(包括隐藏的 `.github` 文件夹)上传到仓库:
   - 网页上传:仓库页点 **uploading an existing file**,把文件夹内容直接拖进去(保持目录结构),点 **Commit changes**;
   - 或命令行:`git init && git add -A && git commit -m init && git remote add origin <你的仓库地址> && git push -u origin main`。
4. 仓库页顶部 **Actions** 标签 → 左侧 **Build unsigned IPA** → 右侧 **Run workflow** → **Run workflow** 确认。
5. 等 3~5 分钟,构建完成 → 点进该次运行 → 底部 **Artifacts** → 下载 `DeepSeekHarnessClient-unsigned-ipa`,解压得到 **未签名 IPA**。

> 免费账号每月有 2000 分钟 macOS 构建额度,本项目单次约 3 分钟,足够用很多次。
> 以后改了地址或想更新,改完代码再点一次 Run workflow 即可。

---

## 第三步:自签安装到 iPhone(iOS 16.3.1)

拿到 IPA 后,按你手上已有的自签软件任选其一:

### 方式 A:TrollStore(如果你手机上已装)
TrollStore 支持 iOS 16.3.1,安装后**永久有效、不需要 7 天重签**。
在手机上用"文件"App 或 Safari 找到 IPA → 分享/打开方式选 **TrollStore** → 安装即可。

### 方式 B:爱思助手(Windows 电脑,最省事)
1. 数据线连接手机,爱思助手里打开 **工具箱 → 自签/IPA 签名**(不同版本叫法略有差异)。
2. 选刚下载的 IPA → 用你的 Apple ID 签名(免费账号即可)→ 安装。
3. 手机上:**设置 → 通用 → VPN 与设备管理** → 找到你的 Apple ID → 点**信任**。
4. 免费证书 **7 天有效**,到期后连电脑重签一次;付费开发者账号(99 美元/年)则 1 年有效。

### 方式 C:Sideloadly / AltStore(Windows 电脑)
用 Apple ID 登录后把 IPA 拖进去签名安装,后续同样需要在 **VPN 与设备管理** 里信任开发者证书。AltStore 需要手机与电脑同网并保持 AltServer 运行,7 天自动续签。

---

## 第四步:手机上使用

1. 打开 **DS Harness**(深蓝底 "DS" 图标)。
2. 首次启动会出现连接页,填入电脑地址:`192.168.2.92:19390` → 点**连接**。
   (IP 以电脑实际为准;桥接用管理员 netsh 方式则填 `:19390`,若你改过端口就填对应端口。)
3. 之后就和在电脑浏览器里一样用了;底部工具栏 ⟳ 刷新、⚙ 改地址。
4. 想要更像原生 App:Safari 方式同样把 `http://192.168.2.92:19390` **添加到主屏幕**作备用入口。

---

## 常见问题排查

| 现象 | 原因 / 解决 |
| --- | --- |
| 手机浏览器打不开 `192.168.2.92:19390` | 桥接窗口没开着;防火墙没放行(控制面板 → Windows Defender 防火墙 → 允许应用通过防火墙 → 勾选 node.exe 的"专用") |
| 提示"无法连接到电脑"错误页 | 电脑上 Harness 没在运行;或桥接目标端口不是 19387 |
| 昨天能用今天连不上 | 电脑 IP 变了(DHCP)。在路由器里给电脑固定 IP,或手机客户端 ⚙ 里改新地址 |
| 聊天回复卡住不动 | 走了 netsh portproxy 且没转发 WebSocket → 改用 `pc-bridge.mjs`(已处理 WebSocket) |
| 电脑休眠后断开 | 设置 → 系统 → 电源,把"睡眠"设为"从不"(插电时) |
| 安全提醒 | 这是局域网明文 HTTP,请在**家庭可信 Wi-Fi** 使用,不要在公共网络暴露 |

---

## 免责与边界

- 本客户端只是网页外壳,不含、也无法包含 Harness 的 agent 引擎;所有会话数据都保存在电脑上。
- IPA 为未签名产物,签名与分发请遵守 Apple 开发者条款及所在地区法规。
