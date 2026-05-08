# Timap

[English](README_en.md) · 中文

![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Release](https://img.shields.io/github/v/release/JVever/Timap?label=release)

> **一秒看见全队此刻几点。**
> 菜单栏点一下，世界地图上你的同事正在睡觉、吃午饭还是开会，一目了然。拖一下时间轴，下周二的全员会该约几点，绿色高亮自己跳出来。

<p align="center">
  <img src="docs/screenshots/01-hero.png" width="520" alt="Timap 主界面：北京为家城市，柏林和纽约的同事各自不同状态，时间滑块上 4 小时的全员重叠窗口绿色高亮" />
</p>

## 能干什么

- **🌍 全队定位实时上图** — 一张会动的世界地图，pin 跟着昼夜走。打开 app 的那一秒，谁在深夜、谁在午休、谁刚坐到工位，一眼分得清。
- **🎚 时间轴随手拖** — 滑块一推，所有城市卡同步切换状态。"下周二北京晚 10 点，纽约的 Maya 还醒着吗？"—— 拖过去，答案在卡上。
- **✨ 自动找全员重叠窗口** — 把所有同事的工作时段以 30 分钟为步进求交集，按重叠人数和连续长度排序。点左上角时间数字，一键跳到下一个推荐窗口。
- **🌐 中英双语 + IANA 时区** — UI 双语切换，时区不是写死的 UTC+8 —— 柏林、伦敦、纽约的夏令时跳转跟着真实日期自动走。
- **🏠 安静住在菜单栏** — 没有 Dock 图标，不抢空间。需要时点开 popover，Esc 收起，点外面任何地方也收。

## 安装

### 方式一：下载 DMG（推荐）

1. 从 [Releases](https://github.com/JVever/Timap/releases) 下载 `Timap-0.1.0.dmg`
2. 打开 DMG → 把 `Timap.app` 拖到 Applications
3. 双击 Timap 打开（**第一次打开会弹一个"无法打开"对话框**，看下方处理方法）
4. 打开成功后，菜单栏顶部会出现 Timap 图标，点开即可使用

#### 第一次打开会弹"无法打开"对话框 — 这样处理

第一次双击 Timap 时，macOS 会拦一下，弹出类似这样的提示（具体文案因系统版本略有不同）：

> "无法打开 Timap，因为它来自身份不明的开发者"
>
> "Apple 无法检查 Timap 是否包含恶意软件"

这是 macOS 对所有不是从 App Store 装的软件都会做的安全检查，**不是 Timap 出了问题**。**只需要处理一次**，之后双击就直接打开了。

下面三种方法**任选一种**：

<details>
<summary><b>方法 A：右键打开 — 最简单，推荐先试这个</b></summary>

适用于大多数 macOS 13 / 14 系统。

1. 打开 Finder → `/Applications` 文件夹，找到 `Timap.app`
2. **按住 `Control` 键并点击**（或在触控板上用两指点击）`Timap.app`
3. 在弹出的菜单里选 **"打开"**
4. 这次的警告对话框会多一个 **"打开"** 按钮 —— 点它
5. 之后双击就能正常启动了

> 注意：必须是从右键菜单进入"打开"，才会出现可以点的"打开"按钮。直接双击弹出的对话框只有"取消"和"移到废纸篓"。

</details>

<details>
<summary><b>方法 B：系统设置里点"仍要打开" — 方法 A 不行就用这个</b></summary>

适用于 macOS 14 (Sonoma) 和 15 (Sequoia)。这些版本里方法 A 有时找不到"打开"按钮，需要从系统设置里放行。

1. 双击 `Timap.app`，让弹出的拦截对话框出现，先点"完成"或"取消"关掉它
2. 打开 **系统设置（System Settings）** → 左侧选 **隐私与安全性（Privacy & Security）**
3. 在右侧页面**滚动到底部**，找到"安全性"区域，会看到一行写着：
   > "Timap"已被阻止使用，因为它来自身份不明的开发者。
4. 点击右侧的 **"仍要打开"** 按钮
5. 系统再弹一次确认对话框，点 **"打开"**（可能需要输入 Mac 密码或 Touch ID 验证）
6. 之后双击就能正常启动了

</details>

<details>
<summary><b>方法 C：终端一行命令 — 适合熟悉命令行的人</b></summary>

适用于所有 macOS 版本。

打开 **终端（Terminal.app）**，粘贴并回车：

```sh
xattr -d com.apple.quarantine /Applications/Timap.app
```

执行后再双击 Timap 就能直接打开。

如果提示 `No such xattr` 或 `No such file or directory` —— 说明 Timap 已经不需要处理了，直接双击就好。

> **这条命令在做什么？** macOS 会给所有从浏览器下载的文件加一个"来自互联网"的隐藏标记，导致系统多一道安全检查。这条命令把 Timap 身上的这个标记去掉，让系统当它是普通的本地软件。**只对这一份 Timap.app 生效，不会影响你 Mac 整体的安全设置。**

</details>

> **三种都试过还是打不开？** 可能是 DMG 下载中断了文件损坏，或者你用的 macOS 版本引入了新限制。麻烦在 [Issues](https://github.com/JVever/Timap/issues) 里留个言，告诉我你的 macOS 版本号和看到的具体报错文字，我会跟进修。

### 方式二：从源码构建

```sh
git clone https://github.com/JVever/Timap.git
cd Timap/Timap
make run
```

需要 macOS 13+ 和 Xcode Command Line Tools（`xcode-select --install`）。

## 三步上手

### 1. 选你所在的城市

第一次打开是欢迎页：logo 装配动画 + 三句价值主张（看清每个城市当下是清晨午后还是深夜 / 一眼找到全员都在工作时间的会议时段 / 常驻菜单栏随时拉出收起）。下一步选你所在的城市，作为本地时区。

<p align="center">
  <img src="docs/screenshots/06-onboarding-welcome.png" width="240" alt="欢迎页 · logo 装配完成" />
  <img src="docs/screenshots/07-onboarding-citypick.png" width="240" alt="城市选择 · 5 个常用城市芯片 + 完整城市列表" />
  <img src="docs/screenshots/08-onboarding-citypick-selected.png" width="240" alt="选中北京后底部出现绿色预览卡 + 激活的「开始使用」按钮" />
</p>

<p align="center"><sub>欢迎页 → 选你的城市 → 确认进入主界面</sub></p>

### 2. 添加同事

进入 Settings（齿轮图标）→ 在每张城市卡上点 "+ 同事" 加入团队成员；底部 "+ 添加新城市" 加更多城市。每位同事的工作时段可独立设置（30 分钟步进），头像支持上传图片或姓名首字母自动生成。内置城市库里没有的城市可以手动添加经纬度。

<p align="center">
  <img src="docs/screenshots/04-settings.png" width="420" alt="设置页：每个城市一张卡，工作时段可调，同事标签支持头像和名字" />
</p>

### 3. 看图办事

回主界面：

| 操作 | 结果 |
|---|---|
| 拖滑块 | 所有城市卡同步切换状态 |
| 点左上角时间数字 | 一键跳到下一个推荐会议时段 |
| 点城市名字 | 隐藏 / 包含该城市（隐藏的不参与重叠计算，但仍显示在地图上） |
| 点 "现在" 按钮 | 回到当前实时 |

## License

[GPL-3.0](LICENSE) · Copyright © 2026 [JVever](https://github.com/JVever)

> Timap 是自由软件 —— 你可以自由使用、修改、分发；如果你分发修改版，得继续以 GPL-3.0 开源。
