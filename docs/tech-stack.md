# Echo — 技术栈说明

## 运行环境

- **OS**: HarmonyOS NEXT (API 12+)
- **SDK**: compatibleSdkVersion 5.0.5(17), targetSdkVersion 6.0.0(20)
- **开发工具**: DevEco Studio
- **语言**: ArkTS (TypeScript 严格模式)

## 核心 API

| API | 用途 | 导入方式 |
|-----|------|----------|
| `@ohos.pasteboard` | 系统剪贴板读写与监听 | `import pasteboard from '@ohos.pasteboard'` (默认导入) |
| `@ohos.data.relationalStore` | 关系型数据库（RDB） | `import relationalStore from '@ohos.data.relationalStore'` (默认导入) |
| `@ohos.data.preferences` | 键值存储（设置） | `import preferences from '@ohos.data.preferences'` (默认导入) |
| `@ohos.multimedia.image` | 图片处理（PixelMap 保存） | `import image from '@ohos.multimedia.image'` (默认导入) |
| `@ohos.file.fs` | 文件系统操作 | `import fileIo from '@ohos.file.fs'` (默认导入) |
| `@kit.AbilityKit` | 应用上下文 | `import { common } from '@kit.AbilityKit'` (命名导入) |
| `@kit.ArkUI` | UI 组件框架 | `import { AppStorageV2, window } from '@kit.ArkUI'` |
| `@kit.PerformanceAnalysisKit` | 日志 | `import { hilog } from '@kit.PerformanceAnalysisKit'` |

## 权限

| 权限 | 用途 |
|------|------|
| `ohos.permission.INTERNET` | 基础网络权限 |
| `ohos.permission.READ_PASTEBOARD` | 读取系统剪贴板 |

## 项目结构

```
Echo/
├── AppScope/                    # 应用级全局配置
├── entry/                       # 主模块
│   └── src/main/
│       ├── module.json5         # 模块描述（Ability、权限、路由）
│       └── ets/
│           ├── constant/        # 常量定义
│           ├── entryability/    # UIAbility 入口
│           ├── model/           # 数据模型
│           ├── database/        # 数据库操作
│           ├── viewmodel/       # 业务逻辑
│           ├── pages/           # 页面组件
│           └── component/       # 通用 UI 组件
├── docs/                        # 项目文档
├── dev-logs/                    # 开发日志
└── CLAUDE.md                    # AI 工作指引
```

## ArkTS 限制

- 禁止 `Object.assign` — 属性需逐个赋值
- 禁止 `any` / `unknown` — 所有变量需显式类型
- 禁止无类型对象字面量 — 需对应到类或 Record 类型
- 对象字面量不可用作类型声明 — 需用 interface
- `@ohos.*` 模块大多使用**默认导出** — 用 `import X from 'module'`
- `@kit.*` 模块使用**命名导出** — 用 `import { X } from 'kit'`
