# Echo — AI 助手工作指引

## 项目简介

Echo 是一款运行在华为鸿蒙（HarmonyOS）系统上的历史剪贴板管理 App。
它可以自动记录用户复制的内容（文字和图片），支持分类管理、搜索、置顶、存储时效设置。

## 文档索引

| 文档 | 路径 | 说明 |
|------|------|------|
| 需求文档 | [docs/requirements.md](docs/requirements.md) | 功能需求、UI 布局、数据模型 |
| 技术栈 | [docs/tech-stack.md](docs/tech-stack.md) | SDK、API、依赖、项目结构 |
| 设计规范 | [docs/design-standards.md](docs/design-standards.md) | 颜色、组件、交互、命名规范 |
| 开发指南 | [docs/dev-guide.md](docs/dev-guide.md) | 执行步骤、命令、验证方式 |
| 开发日志 | [dev-logs/](dev-logs/) | 每日完成事项和待办记录 |

## 开发原则

1. **小步推进** — 每次只改动最少文件，改完立即编译验证
2. **编译不过不进下一步** — 每个步骤的硬性门槛
3. **优先参考 Example 项目** — `../Example/` 是经过验证的参考代码
4. **ArkTS 严格模式** — 所有代码必须通过 `@ComponentV2` / `@ObservedV2` 严格类型检查
5. **先跑通再优化** — 先让 App 在虚拟机上运行起来，再逐步完善功能

## 每日日志规则

- 每次会话结束时，在 `dev-logs/` 下创建或更新当日日志（文件名：`YYYY-MM-DD.md`）
- 记录内容：今天完成的事项、当前待办、遇到的问题及解决方案
- 格式简洁，用中文记录

## 常见问题速查

### ArkTS 编译错误
- `arkts-limited-stdlib` → 检查是否用了 `Object.assign` 等受限 API
- `arkts-no-any-unknown` → 所有变量必须有显式类型
- `arkts-no-untyped-obj-literals` → 对象字面量需要对应到类或接口
- `Type 'X' is not assignable to type 'Y'` → 检查类型转换，用 `Number()` 而非 `as number`
- `Property 'X' does not exist on type` → API 名称可能已变更，查看编译器建议的替代名

### 模块导入
- `@ohos.data.relationalStore` → 默认导入: `import relationalStore from '...'`
- `@ohos.pasteboard` → 默认导入: `import pasteboard from '...'`
- `@ohos.multimedia.image` → 默认导入: `import image from '...'`
- `@ohos.file.fs` → 默认导入: `import fileIo from '...'`
- `@ohos.data.preferences` → 默认导入: `import preferences from '...'`
- `@kit.AbilityKit` / `@kit.ArkUI` / `@kit.PerformanceAnalysisKit` → 命名导入

### 组件命名冲突
- `clip` 是系统内置属性，自定义参数请用 `clipItem` 等其他名称

### 剪贴板监听架构
- **双层监听**: 事件驱动 (`on('update')`) + 定时轮询 (`setTimeout` 2.5s)
- **真机路径**: `on('update')` 事件触发 → `readAndSaveClipboard()`
- **虚拟机兜底**: `setTimeout` 递归轮询 → `readAndSaveClipboard()`
- **前台恢复**: `Index.onPageShow()` → `ClipboardViewModel.onForeground()` → 即时检查 + 重启监听
- **去重**: 内存级 (`lastContent`) + 数据库级 (60s 内相同内容去重)
- **文本提取**: `PasteData.getPrimaryText()` 为主，`record.plainText` 属性为兜底

### 运行时权限
- `ohos.permission.READ_PASTEBOARD` 是 user_grant 权限（API 12+）
- 启动时通过 `abilityAccessCtrl.requestPermissionsFromUser()` 弹窗请求
- 权限通过后才启动剪贴板监听；被拒绝则禁用监听
- 权限请求代码模式：先 `checkAccessTokenSync` 检查，未授权再 `requestPermissionsFromUser`
- `abilityAccessCtrl.PermissionRequestResult` 类型可能未导出 → 用类型推断代替显式标注

### API 兼容性
- `SystemPasteboard.getData(callback)` — 使用 callback 风格（已验证兼容）
- `SystemPasteboard.setData(data, callback)` — 使用 callback 风格
- `PasteData.getPrimaryText()` — 主路径，虚拟机可能返回空
- `PasteDataRecord.plainText` — 兜底路径（属性，非方法）

### 数据流架构
- **DB = 仅持久化**，内存是 UI 唯一数据源
- `fullClips`（私有）: 全量主列表，所有增删改操作更新此列表
- `clips`（@Trace）: UI 展示列表，由 `applyFilters()` 从 `fullClips` 过滤生成
- `applyFilters()`: pinned 优先 → 按 searchKeyword / selectedCategoryId 过滤 → 写入 `clips`
- `saveClip()`: DB.insert → `clip.id = rowId` → 更新 `fullClips` → `applyFilters()`
- `togglePin/moveToCategory/deleteClip`: DB 操作 → 重建 fullClips 中的对象（新引用触发 ForEach 重渲染） → `applyFilters()`
- `onSearch/onFilterCategory`: 设置筛选标志 → `applyFilters()`（纯内存，不查 DB）
- `loadClips()`: **仅 init() 时调用一次**，从 DB 加载到 `fullClips`
- 关键原则：对象属性变更时必须创建新实例，否则 ForEach 不重渲染
- **乐观更新**：所有写操作必须先更新 UI（同步），再异步写 DB。反模式是先 await DB 再更新 UI，导致 50-200ms 感知延迟

### ArkUI 注意事项
- `List` 内的 `ForEach` **必须**提供显式 key 函数，否则多个 item 渲染异常
- 模式: `ForEach(arr, item => { ... }, (item): string => item.id.toString())`
- `@ObservedV2` class 的 `@Trace` 属性变更触发 UI 刷新
- 数组引用变更（`this.clips = newArray`）触发 `ForEach` 全量 diff
- **关键陷阱**: `ForEach` + key 函数会复用同 key 的 DOM 节点，此时 `@Builder` 函数**不会重新执行** → 数据变更后 UI 不更新
  - 解决方案：将需要响应数据变更的内容**内联**到 ForEach 回调中，而非抽成 `@Builder`
  - 或使用 `@ComponentV2` 组件（`@Param` 变更会触发组件重渲染）

## 一次开发多端部署（一多）

### 概念

鸿蒙"一次开发，多端部署"分为三个核心层次：

| 层次 | 核心内容 | 关键概念 |
|------|---------|---------|
| **界面级** | 适配不同屏幕尺寸和色彩风格 | 响应式布局（断点、栅格 `GridRow`/`GridCol`）、自适应布局（拉伸/均分/占比/缩放/延伸/隐藏/折行）、交互归一（`onClick`/`onHover` 统一处理触控和鼠标） |
| **功能级** | 处理不同设备的系统能力差异 | `SysCap` 机制、`canIUse` 接口判断设备是否支持某能力（蓝牙、NFC等） |
| **工程级** | 一套代码部署多种设备 | 三层架构：**Common**（公共层）→ **Features**（基础特性层）→ **Products**（产品定制层）；HAP 按需部署 |

### Echo "一多"可行性总览

**结论：完全可行，且已有良好基础。**

#### 已有基础

| 项目 | 现状 | 评价 |
|------|------|------|
| `deviceTypes` | `["phone", "tablet"]` | ✅ 已声明支持手机和平板 |
| SDK 版本 | API 12+ / targetSdk 6.0.0(20) | ✅ 支持全部设备类型 |
| 核心 API | pasteboard / RDB / file.fs / image | ✅ 均为系统级 API，跨设备统一 |
| 权限模型 | `READ_PASTEBOARD` (user_grant) | ✅ 所有设备类型均可弹窗授权 |

#### 各设备可行性

| 设备 | 状态 | 说明 |
|------|:----:|------|
| 手机 (Phone) | ✅ 已实现 | 当前 Echo 的完全形态 |
| 平板 (Tablet) | ✅ 可运行，需 UI 适配 | 单栏布局直接拉伸会过宽，需引入**分栏布局**（如左侧分类列表 + 右侧内容卡片） |
| 折叠屏 (Foldable) | ✅ 可运行，需 UI 适配 | 折叠态等同手机（已适配），展开态等同小平板；需监听折叠状态变化动态切换布局 |
| 电脑/二合一 (2in1/PC) | ⚠️ 需最多适配 | 需补：鼠标右键菜单（替代长按）、`onHover` 悬停效果、键盘走焦和快捷键、自由窗口缩放响应式断点；需添加 `"2in1"` 到 deviceTypes |

#### 核心功能跨设备兼容性

| 核心功能 | 手机 | 平板 | 折叠屏 | PC(2in1) |
|----------|:---:|:---:|:-----:|:--------:|
| 剪贴板事件监听 `on('update')` | ✅ | ✅ | ✅ | ✅ |
| 轮询兜底 `setTimeout 2.5s` | ✅ | ✅ | ✅ | ✅ |
| RDB 数据库读写 | ✅ | ✅ | ✅ | ✅ |
| 图片保存/读取 (file.fs) | ✅ | ✅ | ✅ | ✅ |
| PixelMap 写回剪贴板 | ✅ | ✅ | ✅ | ✅ |
| 运行时权限弹窗 | ✅ | ✅ | ✅ | ✅ |
| 长按操作（置顶/分类/删除） | ✅ | ✅ | ✅ | ⚠️ 需右键菜单替代 |
| 后台监听 | ✅ | ✅ | ✅ | ⚠️ 窗口最小化行为需验证 |

### 利用华为手机 + 平板 + 电脑虚拟机实现

#### DevEco Studio 虚拟机支持

| 虚拟机类型 | 是否可用 | 说明 |
|------------|:-------:|------|
| Phone 模拟器 | ✅ | 已在用，Echo 开发的基础环境 |
| Tablet 模拟器 | ✅ | Device Manager 中下载 Tablet 镜像即可 |
| Foldable 模拟器 | ✅ | 支持折叠/展开切换，可在运行时测试布局变化 |
| 2in1/PC 模拟器 | ✅ | DevEco Studio 较新版本提供，模拟键鼠交互 |

#### 测试方案

手机和平板各有真机覆盖最核心场景，折叠屏和 PC 用虚拟机验证即可。不需要购置全部真机设备，完全可以实现。

### "一多"实施优先级

| 优先级 | 任务 | 工作量 | 说明 |
|--------|------|--------|------|
| P0 | 添加 `"2in1"` 到 deviceTypes | 1 行 | 解锁 PC 部署能力 |
| P1 | 引入断点系统 + 栅格布局 | 1-2 天 | 用 `GridRow`/`GridCol` 改造首页 |
| P1 | 平板分栏布局 | 0.5 天 | 宽屏下分类栏常驻左侧 |
| P2 | 折叠屏折叠态切换监听 | 0.5 天 | 监听窗口宽度变化自动切换 |
| P2 | PC 右键菜单 + 键盘走焦 | 1 天 | 替代长按操作，补 `onHover` |
| P3 | 三层工程架构重构 | 2-3 天 | Common/Features/Products 拆分（可选） |

### 响应式布局常用模式

- **缩进布局**：内容区域在宽屏下增加左右边距
- **挪移布局**：元素从上方/下方挪到左/右侧
- **重复布局**：宽屏下卡片从单列变为多列
- **分栏布局**：左侧固定导航 + 右侧内容区

### 自适应布局七种能力

拉伸、均分、占比、缩放、延伸、隐藏、折行

### 交互归一关键 API

- `onClick` — 统一处理触控点击和鼠标点击
- `onHover` — 鼠标悬停（PC 专属，移动端忽略）
- `onTouch` / `gesture` — 手势操作（长按、滑动）
- 键盘走焦：`focusable` + `onKeyEvent`

## 多端 UI 适配实现报告（v1.2.0 → v1.3.0）

### 设计方向（已确认）

| 决策点 | 选择 |
|--------|------|
| 导航模式 | 平板/PC：侧边垂直导航栏，手机：底部 Tab（不变） |
| 剪贴板宽屏布局 | 多列卡片网格（sm=1列, md=2列, lg=3列） |
| PC 交互 | 右键菜单 + 悬停高亮 + 键盘快捷键 + 窗口缩放自适应（全选） |
| 分类/设置页 | 双列网格/排列 |

### 断点系统

| 断点 | 宽度范围 | 卡片列数 | 导航模式 |
|------|----------|:---:|:---:|
| `sm` | < 600vp | 1 | 底部 Tab |
| `md` | 600–840vp | 2 | 侧边导航（窄 60vp，仅图标） |
| `lg` | > 840vp | 3 | 侧边导航（宽 180vp，图标+文字） |

断点通过 Index 根容器 `onAreaChange` 监听窗口宽度变化，经 `@Param` 向下显式传递。

### 新增文件

| 文件 | 说明 |
|------|------|
| `entry/src/main/ets/common/BreakpointConstants.ets` | 断点枚举、`calcBreakpoint()`、`calcGridColumns()`、`isWideLayout()`、`sideNavWidth()` |
| `entry/src/main/ets/component/SideNav.ets` | 侧边垂直导航栏组件，md 仅图标 / lg 图标+文字 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `entry/src/main/module.json5` | deviceTypes 添加 `"2in1"` |
| `entry/src/main/ets/pages/Index.ets` | `onAreaChange` 断点监听 + 条件渲染（sm→Tabs / md+lg→SideNav+内容区） |
| `entry/src/main/ets/pages/ClipboardPage.ets` | `@Param breakpoint`；`buildSingleColumnList()` + `buildClipGrid()` 双模式；`buildClipContextMenu()`（bindContextMenu）；`onHover` 悬停管理；`onKeyEvent` 键盘快捷键；搜索栏/标签栏/弹窗自适应 |
| `entry/src/main/ets/pages/CategoryPage.ets` | `@Param breakpoint`；`buildSingleColumnList()` + `buildCategoryGrid()` 双模式；弹窗宽度自适应 |
| `entry/src/main/ets/pages/SettingsPage.ets` | `@Param breakpoint`；`buildSingleColumnContent()` + `buildDualColumnContent()` 双模式；弹窗宽度自适应 |
| `entry/src/main/ets/component/ClipCard.ets` | `@Param isHovered`；悬停动画（shadow + scale 1.02 + animation 200ms）；移除自身 `width: '100%'` |

### 各页面布局对比

#### Index（导航容器）

```
手机 (sm):                    平板/PC (md/lg):
┌──────────────────┐          ┌────┬──────────────────┐
│                  │          │ 📋 │  剪贴板页面内容    │
│   内容区(Tabs)    │          │ 📂 │  (根据Tab切换)    │
│                  │          │ ⚙  │                  │
├──────────────────┤          └────┴──────────────────┘
│ 📋剪贴板 📂分类 ⚙设置 │
└──────────────────┘
```

#### ClipboardPage（剪贴板列表）

```
sm (单列):          md (双列):              lg (三列):
┌──────────┐        ┌────────┬────────┐      ┌──────┬──────┬──────┐
│ 搜索栏    │        │  搜索栏            │      │    搜索栏          │
│ [标签栏]  │        │  [标签栏]          │      │    [标签栏]        │
├──────────┤        ├────────┼────────┤      ├──────┼──────┼──────┤
│ ┌──────┐ │        │ ┌────┐ │ ┌────┐ │      │┌────┐│┌────┐│┌────┐│
│ │卡片1 │ │        │ │卡1 │ │ │卡2 │ │      ││卡1 │││卡2 │││卡3 ││
│ └──────┘ │        │ └────┘ │ └────┘ │      │└────┘│└────┘│└────┘│
│ ┌──────┐ │        │ ┌────┐ │ ┌────┐ │      │┌────┐│┌────┐│┌────┐│
│ │卡片2 │ │        │ │卡3 │ │ │卡4 │ │      ││卡4 │││卡5 │││卡6 ││
│ └──────┘ │        │ └────┘ │ └────┘ │      │└────┘│└────┘│└────┘│
└──────────┘        └────────┴────────┘      └──────┴──────┴──────┘
```

#### CategoryPage（分类管理）

```
sm (单列行):        md/lg (双列卡片):
┌──────────┐        ┌────────┬────────┐
│ 分类管理  │        │  分类管理   ＋新建 │
├──────────┤        ├────────┼────────┤
│ ● 默认   │        │┌──────┐│┌──────┐│
│ ● 工作   │        ││●默认 │││●工作 ││
│ ● 个人   │        ││     │││ ✎🗑 ││
│ ● 学习   │        │└──────┘│└──────┘│
└──────────┘        │┌──────┐│┌──────┐│
                     ││●个人 │││●学习 ││
                     ││ ✎🗑 │││ ✎🗑 ││
                     │└──────┘│└──────┘│
                     └────────┴────────┘
```

### PC 交互实现

| 交互 | 实现 |
|------|------|
| 右键菜单 | `bindContextMenu(Menu, ResponseType.LongPress)` — 移动端长按 + PC 右键统一触发 |
| 悬停高亮 | `onHover` → `hoveredClipId` → ClipCard `isHovered` → `shadow` + `scale(1.02)` + `animation(200ms)` |
| 键盘快捷键 | 根容器 `focusable(true).onKeyEvent()` → Escape 关闭弹窗、Delete 删除悬停卡片 |
| 窗口缩放 | `onAreaChange` → `calcBreakpoint()` → 所有依赖断点的布局自动重组 |

### 架构决策

| 决策 | 方案 | 理由 |
|------|------|------|
| 断点定义 | 自定义 3 级 sm/md/lg | 逻辑透明，无需依赖 ArkUI 内置密度系统 |
| 状态传递 | `@Param` 显式传递 breakpoint | ArkTS 严格模式安全 |
| 网格实现 | `Scroll > Row > Column[] > ForEach` | 与现有 Scroll+ForEach 模式一致，避免 GridRow 的 List 回收问题 |
| 列分配 | 轮询法 `i % count` | 简单可靠 |
| 右键菜单 | `bindContextMenu` + `Menu`/`MenuItem` | 鸿蒙交互归一 API，一次绑定覆盖触控+鼠标 |
| 弹窗宽度 | sm=百分比，md/lg=固定vp | 小屏充分利用空间，大屏限制宽度 |
