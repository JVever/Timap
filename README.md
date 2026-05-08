# Timap

[English](README_en.md) · 中文

![Platform](https://img.shields.io/badge/macOS-13.0%2B-blue) ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange) ![License](https://img.shields.io/badge/license-GPL--3.0-green) ![Release](https://img.shields.io/github/v/release/JVever/Timap?label=release)

> **一秒看见全队此刻几点。**
> 菜单栏点一下，世界地图上你的同事正在睡觉、吃午饭还是开会，一目了然。拖一下时间轴，下周二的全员会该约几点，绿色高亮自己跳出来。

<p align="center">
  <img src="docs/screenshots/01-hero.png" width="520" alt="Timap 主界面：北京为家城市，柏林和纽约的同事各自不同状态，时间滑块上 4 小时的全员重叠窗口绿色高亮" />
</p>

## 能干什么

- **🌍 同事所在城市，地图上一目了然** — 一张会动的世界地图，每位同事所在的城市都标在上面，背景的昼夜分界跟着真实时间在地图上移动。打开 app 那一秒就能看出来：谁在深夜、谁在午休、谁刚坐到工位。
- **🎚 时间轴随手拖** — 滑块一推，所有城市卡同步切换状态。"下周二北京晚 10 点，纽约的 Maya 还醒着吗？"—— 拖过去，答案在卡上。
- **✨ 自动找大家都能开会的时段** — 把每位同事的工作时段以 30 分钟为步进求交集，按重叠人数和连续长度排序。点左上角时间数字，一键跳到下一个推荐时段。

## 安装

### 方式一：下载 DMG（推荐）

1. 进入 [Releases 页面](https://github.com/JVever/Timap/releases) → 在最新版本下方的 **Assets**（资源）区域里找到并点击 `Timap-0.1.1.dmg` 下载
2. 打开下载好的 DMG → 把 `Timap.app` 拖到 Applications 文件夹
3. 双击 Timap 打开（**第一次会弹"无法打开"对话框**，看下方处理方法）
4. 处理后再次双击，**欢迎页会自动弹出**；按提示完成首次设置即可。之后 Timap 常驻屏幕**右上角的菜单栏**（图标是黑色框 + 三条横杠样式），点击图标随时打开使用

#### 第一次打开会弹"无法打开"对话框 — 这样处理

第一次双击 Timap 时，macOS 会拦一下，弹出类似这样的提示（具体文案因系统版本略有不同）：

> "无法打开 Timap，因为它来自身份不明的开发者"
>
> "Apple 无法检查 Timap 是否包含恶意软件"

这是 macOS 对所有不是从 App Store 装的软件都会做的安全检查，**不是 Timap 出了问题**。**只需要处理一次**，之后双击就直接打开了。

下面两种方法任选一种：

##### 方法 1：系统设置里点"仍要打开"（推荐）

1. 双击 `Timap.app`，让弹出的拦截对话框出现，先点"完成"或"取消"关掉它
2. 打开 **系统设置（System Settings）** → 左侧选 **隐私与安全性（Privacy & Security）**
3. 在右侧页面**滚动到底部**，找到"安全性"区域，会看到一行写着：
   > "Timap"已被阻止使用，因为它来自身份不明的开发者。
4. 点击右侧的 **"仍要打开"** 按钮
5. 系统再弹一次确认对话框，点 **"打开"**（可能需要输入 Mac 密码或 Touch ID 验证）
6. 之后双击就能正常启动了

##### 方法 2：终端一行命令（适合熟悉命令行的人）

打开 **终端（Terminal.app）**，粘贴并回车：

```sh
xattr -d com.apple.quarantine /Applications/Timap.app
```

执行后再双击 Timap 就能直接打开。

如果提示 `No such xattr` 或 `No such file or directory` —— 说明 Timap 已经不需要处理了，直接双击就好。

> **这条命令在做什么？** macOS 会给所有从浏览器下载的文件加一个"来自互联网"的隐藏标记，导致系统多一道安全检查。这条命令把 Timap 身上的这个标记去掉，让系统当它是普通的本地软件。**只对这一份 Timap.app 生效，不会影响你 Mac 整体的安全设置。**

> **两种都试过还是打不开？** 可能是 DMG 下载中断导致文件损坏，或者你用的 macOS 版本引入了新限制。麻烦在 [Issues](https://github.com/JVever/Timap/issues) 里留个言，告诉我你的 macOS 版本号和看到的具体报错文字，我会跟进修。

### 方式二：从源码构建

```sh
git clone https://github.com/JVever/Timap.git
cd Timap/Timap
make run
```

需要 macOS 13+ 和 Xcode Command Line Tools（`xcode-select --install`）。

### 装好之后菜单栏看不到 Timap 图标？

带刘海的 MacBook（Pro 14"/16" 或 Air 13"/15"）如果菜单栏图标多，Timap 图标可能躲在刘海背后看不见、点不着。两条路都能解：

- **不靠菜单栏图标也能打开** — 直接**双击 `/Applications/Timap.app`**，或者从 Spotlight / Launchpad 启动 Timap，主界面会自动弹出。
- **彻底解决：装个菜单栏管理工具**（一次配置、长期受益），推荐免费开源的两个：
  - [Hidden Bar](https://github.com/dwarvesf/hidden) — 简单，专做隐藏 / 显示
  - [Ice](https://github.com/jordanbaird/Ice) — 功能更全

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

### 3. 用起来

回到主界面，几个常用动作：

- **拖滑块** — 所有城市卡同步切到那一刻的状态
- **点左上角时间数字** — 一键跳到下一个全员都在工作时段的推荐窗口
- **点城市名字** — 隐藏 / 包含该城市（隐藏的城市仍显示在地图上，但不参与重叠窗口计算）
- **点「现在」按钮** — 回到当前实时

## License

[GPL-3.0](LICENSE) · Copyright © 2026 [JVever](https://github.com/JVever)

> Timap 是自由软件 —— 你可以自由使用、修改、分发；如果你分发修改版，得继续以 GPL-3.0 开源。
