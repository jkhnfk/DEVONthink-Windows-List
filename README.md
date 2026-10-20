# DEVONthink 窗口列表

<p align="center">
  <img src="docs/screenshot-light.png" width="330" alt="浅色外观下的面板">
</p>

<p align="center">
  <a href="https://github.com/jkhnfk/DEVONthink-Windows-List/releases/latest"><img src="https://img.shields.io/github/v/release/jkhnfk/DEVONthink-Windows-List?label=release" alt="release"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/arch-arm64%20%7C%20x86__64-blue" alt="universal">
  <img src="https://img.shields.io/badge/swift-5.9%2B-orange?logo=swift&logoColor=white" alt="swift 5.9+">
</p>

DEVONthink 的窗口一多，切换就变成了在「窗口」菜单里数标题。这个小工具常驻菜单栏，把 DEVONthink 当前打开的所有窗口收进一个从**屏幕边缘滑出**的面板，鼠标点一下就能切换过去。

面板不会抢走 DEVONthink 的焦点，读完用鼠标离开就自动收起，几乎不占地方。

## 亮点

- **边缘呼出**：鼠标移到屏幕右边缘（可换成左边缘）4pt 的触发区内，面板滑出；移开约 0.45 秒后自动收起。不使用全局事件监听，**不需要辅助功能权限**。
- **按窗口类型分组**：`主窗口` 与 `文档窗口` 分开列出，每行带数据库名；最小化的窗口会标出「已最小化」，点击该行即可还原并置顶。
- **多标签页支持**：窗口下有多个 tab 时，非当前 tab 会以缩进子行列出，点击即可直达对应 tab（当前 tab 已并入窗口行，不重复展示）。
- **一键关闭**：每行右侧提供「关闭」按钮，鼠标悬停即出现，直接关闭对应的窗口或标签页，无需先激活窗口。
- **可选 Skim 集成**：在设置中开启后，会以同样的逻辑列出 Skim 打开的所有 PDF（窗口与标签页），点击即可切换、悬停即可关闭；关闭后只显示 DEVONthink。
- **刷新及时**：面板滑出瞬间刷新一次；显示期间每 1.5 秒同步标题/顺序，并用 `CGWindowList` 以 0.5 秒粒度感知窗口的开关 —— 关掉一个窗口，列表几乎立刻更新。
- **真正的毛玻璃**：`NSVisualEffectView` 的 behind-window 材质，圆角由可拉伸遮罩裁剪，转角的描边是均匀的 1pt 细线，不会出现白色断口。
- **不抢焦点**：面板是 `.borderless + .nonactivatingPanel`，永远不会成为 key window；行视图实现了 `acceptsFirstMouse`，第一次点击就生效。
- **空状态友好**：DEVONthink 未运行 / 未安装 / 自动化权限被拒绝时，面板给出说明和「启动 DEVONthink」「打开系统设置」「重试」按钮。
- **Universal 二进制**：`arm64 + x86_64`，Apple Silicon 与 Intel 通用。

## 截图

| 浅色 | 深色 |
| --- | --- |
| <img src="docs/screenshot-light.png" width="300"> | <img src="docs/screenshot-dark.png" width="300"> |

> 截图由真实的 `PanelContentView` 渲染，窗口内容为示例数据。

## 安装

### 方式一：下载预编译版本（推荐）

1. 打开 [Releases](https://github.com/jkhnfk/DEVONthink-Windows-List/releases/latest)，下载 `DEVONthinkWindowsList-1.2.0-universal.zip`；
2. 解压后把 `DEVONthink 窗口列表.app` 拖进 `/Applications`；
3. 首次启动：应用是 ad-hoc 签名的，没有经过 Apple 公证，Gatekeeper 会阻止。右键点击 App →「打开」，或执行

   ```bash
   xattr -dr com.apple.quarantine "/Applications/DEVONthink 窗口列表.app"
   ```

4. 第一次读取窗口时系统会询问「是否允许控制 DEVONthink」，选择**允许**。

### 方式二：从源码构建

```bash
git clone https://github.com/jkhnfk/DEVONthink-Windows-List.git
cd DEVONthink-Windows-List
Scripts/build-app.sh            # Release，默认 universal
open "build/DEVONthink 窗口列表.app"
```

- `Scripts/build-app.sh debug` 构建 debug 版本；
- `ARCHS=arm64 Scripts/build-app.sh` 只构建本机架构（Intel 用 `ARCHS=x86_64`）；
- `REBUILD_ICON=1 Scripts/build-app.sh` 强制重新生成图标（`Scripts/make-icon.swift` 画图 → `iconutil` 打包成 `Resources/AppIcon.icns`）；
- 脚本会编译 Swift 包、组装 `.app`（`Info.plist` / `PkgInfo` / 图标）并做 ad-hoc 签名，最后打印 `lipo -info`。

> 重新构建会改变 ad-hoc 签名的哈希，macOS 可能把它当成「新的 App」再问一次自动化权限。把 App 放到固定位置后尽量不要反复重建；把 `.app` 拖到别的目录/机器上同理。

## 使用

1. 启动后菜单栏出现一个侧栏图标（无 Dock 图标、无窗口）。
2. 把鼠标移到屏幕右边缘的触发区，面板从右侧滑出。
3. 点击列表中的任意窗口即可切换：面板收起、DEVONthink 激活、目标窗口还原并置顶；点击缩进的标签页可直达对应 tab；鼠标悬停某行并点击右侧「关闭」按钮可直接关闭该窗口或标签页。
4. 点击菜单栏图标可以查看当前窗口列表、手动刷新、显示/隐藏面板、切换面板所在边缘（左/右）、开关自动隐藏、**开关「显示 Skim 窗口」**、设置登录时启动。

## 刷新策略

窗口列表由多条通道共同维护，兼顾「及时」和「省电」：

| 触发 | 频率 | 说明 |
| --- | --- | --- |
| 面板开始滑出 | 立即 | 打开面板第一眼就是最新数据 |
| `CGWindowList` 窗口签名比对 | 0.5 s | 只比较 DEVONthink 顶层窗口的窗口 ID 集合，开窗/关窗立刻发现，**不需要额外权限**，面板隐藏时也生效 |
| 完整 AppleScript 刷新 | 1.5 s（面板可见时） | 兜住标题改名、顺序变化、最小化状态等 ID 不变的情况 |
| 后台刷新 | 20 s（面板隐藏时） | 保持菜单栏菜单与 tooltip 大致准确 |

刷新过程中再次触发不会丢：`refresh()` 用 `needsRefresh` 合并请求，本轮结束后会补刷一次。

## 代码结构

| 文件 | 作用 |
| --- | --- |
| `Sources/DEVONthinkWindowsList/Main.swift` | 入口，以 accessory（无 Dock 图标）方式启动 `NSApplication` |
| `AppDelegate.swift` | 状态栏图标与菜单、刷新调度、状态映射、窗口激活、登录时启动 |
| `PanelController.swift` | 无边框 `NSPanel`、边缘悬停轮询、滑入滑出动画、自动隐藏 |
| `PanelContentView.swift` | 面板内容：标题栏、可滚动列表、页脚、圆角与描边 |
| `WindowRowView.swift` | 单个窗口行（悬停高亮、按下反馈、手型光标） |
| `Views.swift` | 通用组件：翻转视图、分隔线、圆角描边覆盖层、闭包按钮、空状态、`ItemListView` |
| `DEVONthinkScripting.swift` | AppleScript 桥接（读取窗口 / 激活窗口 / 打开自动化设置） |
| `DEVONthinkApp.swift` | DEVONthink 安装与运行状态探测 |
| `Settings.swift` | `UserDefaults` 设置（边缘位置、自动隐藏）与尺寸常量 |
| `Models.swift` | `DTWindowInfo`、`PanelState` |
| `Scripts/build-app.sh` | 编译、`lipo` 合并、组装 `.app`、ad-hoc 签名 |
| `Scripts/make-icon.swift` | 绘制并导出 `AppIcon.icns` |

## 实现要点

**读取窗口**

- AppleScript 在私有串行队列上通过 `NSAppleScript` 执行，UI 不会被 DEVONthink 或系统授权弹窗阻塞。
- 字段用 `U+0001`、记录用 `U+0002` 分隔，所以窗口标题里的逗号、引号、换行都不会破坏解析；每个窗口的属性读取都包在 `try` 里，个别窗口缺少 `name` / `database` 不会中断整个结果。
- Apple Event 错误 `-1743` / `-1744` 会被识别为自动化权限问题，展示「需要授权」空状态。

**面板与交互**

- 面板是 `.borderless + .nonactivatingPanel`，`canBecomeKey` 返回 `false`，点击不会把焦点从 DEVONthink 抢走；行视图实现 `acceptsFirstMouse`，第一次点击即生效。
- 边缘检测用 70ms 的 `NSEvent.mouseLocation` 轮询，而不是全局事件监视器 —— 因此**不需要辅助功能权限**。
- 列表使用固定行高（34pt）的自行布局容器 `ItemListView`，避免在 `NSScrollView` 里混用 Auto Layout 造成的布局冲突。

**外观**

- 毛玻璃放在独立的 `NSVisualEffectView` 里，用 `maskImage`（可拉伸的 14pt 圆角遮罩）裁剪，材质本身也是圆角。
- 描边不用 `layer.borderWidth`（贴着边缘绘制，转角处会被圆角遮罩削弱，看起来像断口），而是由 `BorderOverlayView` 在距边缘 1pt 处描 1pt 圆角线，颜色按明暗外观取白色 14% / 黑色 8%。
- 面板高度由内容计算（`preferredHeight`），同样的 4 个窗口约 264pt 高；超过屏幕可用高度时自动滚动。

**刷新**

- 见上文[刷新策略](#刷新策略)：0.5 秒的窗口 ID 签名 + 1.5 秒的 AppleScript 全量刷新 + 20 秒后台兜底。
- `CGWindowListCopyWindowInfo` 只读取窗口元数据，不需要屏幕录制权限，也不会唤醒 DEVONthink。

## 系统要求

- macOS 13 Ventura 或更高版本
- DEVONthink 4（`com.devon-technologies.think`）或 DEVONthink 3（`com.devon-technologies.think3`）
- 从源码构建需要 Xcode 命令行工具（Swift 5.9+）：`xcode-select --install`
- 首次读取窗口时需要在系统弹窗中允许「自动化」

## 已知限制

- 面板宽度固定为 300pt（`Settings.panelWidth`），不可拖动或调整大小。
- 面板只出现在鼠标所在的那块屏幕上。
- 面板不接收键盘焦点，列表仅支持鼠标操作。
- 窗口信息完全来自 DEVONthink 的 AppleScript 字典，DEVONthink 未运行时只能显示空状态。
- ad-hoc 签名、无自动更新；升级需要手动下载新版本。

## 常见问题

**鼠标移到边缘，面板没有出现？**
确认菜单栏图标还在、菜单里「自动隐藏」的状态符合预期；触发区是边缘往里 4pt，需要真的贴到屏幕边缘。全屏应用或处于调度中心的 Space 里，浮窗可能被盖住。

**面板一直显示「需要授权」或列表为空？**
打开「系统设置 › 隐私与安全性 › 自动化」，勾选「DEVONthink 窗口列表」下的 DEVONthink。若列表里根本没有这一项，可以先在面板里点「打开系统设置」，或执行：

```bash
tccutil reset AppleEvents com.jkhnfk.DEVONthinkWindowsList
```

然后重新启动 App，让它再问一次。

**提示「App 已损坏，无法打开」？**
这是没去隔离属性的 ad-hoc 签名应用的典型提示，执行：

```bash
xattr -dr com.apple.quarantine "/Applications/DEVONthink 窗口列表.app"
```

**每次重新构建都要重新授权？**
ad-hoc 签名没有稳定的证书，二进制一变签名哈希就变，系统会当成新 App。把 `.app` 固定放在 `/Applications`，稳定使用后就不再打扰。

**Intel Mac 能用吗？**
可以，Release 里的二进制是 universal（`arm64` + `x86_64`）。

**会不会拖慢系统 / 更费电？**
面板隐藏时只有 0.5 秒一次的 `CGWindowList` 元数据比对和 20 秒一次的后台刷新；面板展开时才有 1.5 秒一次的 AppleScript 查询。两者都是毫秒级操作。

## 更新日志

### 1.2.0 — 2026-10-19

- 新增「显示 Skim 窗口」设置：开启后以相同逻辑列出 Skim 打开的所有 PDF（窗口与标签页），点击切换、悬停关闭
- 强化解析健壮性：布尔字段归一化、id 唯一性修复、解析失败显式降级、Skim 读取失败不再静默
- 抽出 Core 模块并引入单元测试

### 1.1.0 — 2026-10-19

- 每行新增「关闭」按钮：鼠标悬停时出现，可直接关闭对应的窗口或标签页，无需先激活窗口
- 支持列出多 tab 窗口下的所有标签页：点击即可跳转到对应 tab（当前 tab 已并入窗口行，不重复展示）
- 修复多 tab 窗口下标签页名称读取不正确、全部显示为窗口名的问题

### 1.0.0 — 2026-10-19

首个公开版本。

- 屏幕边缘呼出面板，列出 DEVONthink 的主窗口与文档窗口，点击即切换
- 最小化窗口可在列表中直接还原并置顶
- 滑出瞬间刷新；0.5 秒感知窗口开关，1.5 秒同步标题与顺序
- 紧凑布局（行高 34pt），圆角毛玻璃 + 均匀 1pt 描边
- Universal 二进制（`arm64` + `x86_64`），最低 macOS 13

---

如果这个小工具帮你省下了在「窗口」菜单里翻找的时间，欢迎点个 ⭐。



