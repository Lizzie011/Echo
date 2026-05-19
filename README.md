# Echo — 历史剪贴板管理 App

> HarmonyOS NEXT · ArkTS · 版本 1.2.0

## 设计初衷

主播在完成作业时接触了 Agent，使用过程中发现很多指令其实反复出现、内容重复，便灵机一动，决定借助 Agent 做一个剪贴板管理小工具，于是「Echo」诞生了。

「Echo」的中文意为「回声」，寓意着这款 App 所具备的记忆与回溯能力——每一次复制都是一次发声，而 Echo 让每一次发声都有回响。

## 简介

Echo 是一款运行在华为鸿蒙系统上的**历史剪贴板管理**应用。它能自动记录你在手机上复制的文字和图片，支持分类管理、全文搜索、置顶收藏、存储时效设置。

## 功能一览

| 功能 | 说明 |
|------|------|
| 🔍 自动记录 | 前台 + 后台运行期间，自动监听系统剪贴板变化，记录文字和图片 |
| 📋 时间线 | 所有内容按时间倒序卡片排列，最新复制的内容在最上面 |
| 👆 点击复制 | 点击任意卡片即可将内容写回系统剪贴板，随处粘贴 |
| 🔎 搜索 | 顶部搜索栏支持对文字内容进行关键词模糊搜索 |
| 📌 置顶 | 长按卡片 → 置顶，置顶内容始终排在最前面 |
| 🗂 分类管理 | 创建/重命名/删除分类，每类可自定义颜色标签 |
| 📂 移入分类 | 长按卡片 → 移动到指定分类 |
| 🏷 分类筛选 | 顶部分类标签栏，点击即可按分类查看内容 |
| ⏱ 存储时效 | 全局设置保留天数（1/3/5/7 天 / 永不过期），过期自动清理 |
| 🗑 删除 | 长按卡片 → 删除，支持一键清空 |
| 🖼 图片支持 | 自动记录复制的图片，卡片内显示缩略图，可复制回剪贴板粘贴 |

## 技术栈

| 类别 | 技术 |
|------|------|
| 运行环境 | HarmonyOS NEXT (API 12+), SDK 6.0.0(20) |
| 开发语言 | ArkTS (TypeScript 严格模式) |
| UI 框架 | ArkUI V2 (`@ComponentV2` / `@ObservedV2` / `@Trace`) |
| 数据库 | 关系型数据库 RDB (`@ohos.data.relationalStore`) |
| 剪贴板 | `@ohos.pasteboard` (事件 + 轮询双层监听) |
| 本地存储 | `@ohos.data.preferences` (设置) / `@ohos.file.fs` (图片文件) |
| 日志 | `@kit.PerformanceAnalysisKit` (hilog) |

## 项目结构

```
Echo/
├── AppScope/                       # 应用级配置
├── entry/src/main/
│   ├── module.json5                # 模块描述（权限、路由）
│   ├── ets/
│   │   ├── constant/               # 常量（颜色、默认值）
│   │   ├── entryability/           # UIAbility 入口
│   │   ├── model/                  # 数据模型（ClipItem, CategoryItem）
│   │   ├── database/               # 数据库层（CRUD）
│   │   ├── viewmodel/              # 业务逻辑（剪贴板监听、分类管理）
│   │   ├── pages/                  # 页面（剪贴板、分类、设置、主页）
│   │   └── component/              # 通用组件（ClipCard, SearchBar）
│   └── resources/                  # 字符串、颜色资源
├── docs/                           # 需求文档、技术栈说明
├── dev-logs/                       # 开发日志
└── CLAUDE.md                       # AI 协作指引
```

## 架构设计

### 数据流

```
剪贴板变化 (事件 / 2.5s轮询)
    ↓
readAndSaveClipboard()
    ↓ getPrimaryText() / record.plainText 双重提取
    ↓
saveClip()
    ├── 内存去重 (lastContent)
    ├── DB 持久化 (addClip)
    └── fullClips 主列表更新 → applyFilters() → clips (@Trace UI 列表)
    ↓
Scroll + Column + ForEach(key=id) 渲染卡片
```

### 核心设计原则

- **DB 仅持久化**，内存（`fullClips` + `clips`）是 UI 唯一数据源
- **乐观更新**：所有写操作先更新 UI（同步），再异步写 DB，即时响应
- **对象重建**：属性变更时创建新对象实例，触发 ForEach 重渲染
- **纯内存筛选**：搜索/分类筛选不查 DB，直接在 `fullClips` 上过滤
- **去重机制**：内存级（`lastContent`）+ 数据库级（60s 内相同内容去重）
- **基线机制**：启动时读取剪贴板建立基线，防止 App 关闭期间的旧数据被存入

### 剪贴板监听

- **事件驱动**：`pasteboard.on('update')` 监听剪贴板变化（真机主路径）
- **定时轮询**：`setTimeout` 2.5 秒间隔（虚拟机兜底，事件可能不触发）
- **前台恢复**：`onPageShow → onForeground()` 确保监听活跃
- **后台持续**：不因页面隐藏而停止监听，App 进程存活期间持续记录

## 开发历程

### 2026-05-19：项目搭建 + 核心功能实现

- 搭建项目骨架、数据模型、数据库层、ViewModel、UI 页面
- 实现剪贴板监听（事件 + 轮询双层机制）
- 修复 ArkTS 严格模式下的编译问题
- 重构数据流：引入 `fullClips` + `applyFilters` 内存过滤架构
- 修复 UI 渲染问题：翻页、点击消失、ForEach key、@Builder 陷阱
- 实现置顶、分类筛选、搜索等交互功能

### 2026-05-20：功能完善 + bug 修复

- 所有 ViewModel 写操作统一为乐观更新模式
- 修复后台剪贴板监听逻辑（两次修正，最终方案：基线机制）
- 点击已存内容复制时不重复存入
- 图片显示缩略图 + 复制回剪贴板
- 删除/过期时清理图片磁盘文件
- 修复分类页面编辑后不刷新（ForEach key 加入 name）
- 版本号升级至 1.2.0

### 已知问题

- ⚠️ 重启 App 后图片粘贴功能偶发不稳定，疑似 HarmonyOS 沙箱文件路径或 `MIMETYPE_PIXELMAP` 兼容性限制
- ⚠️ 系统级悬浮窗在 HarmonyOS NEXT 手机设备上不向第三方 App 开放，此功能已搁置

## 构建与运行

1. 使用 DevEco Studio 打开项目目录
2. 等待依赖同步和索引完成
3. 连接 HarmonyOS 虚拟机或真机
4. 点击 Run 按钮编译并运行

首次启动会弹出「允许读取剪贴板」权限对话框，点击允许后即可正常使用。

## 权限

| 权限 | 用途 | 类型 |
|------|------|------|
| `ohos.permission.READ_PASTEBOARD` | 读取系统剪贴板 | user_grant（运行时弹窗请求） |
| `ohos.permission.INTERNET` | 基础网络 | normal |

## 许可证

MIT
