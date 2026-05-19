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
