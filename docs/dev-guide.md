# Echo — 开发执行指南

## 环境准备

1. 安装 DevEco Studio（已安装）
2. 打开项目：`File → Open → 选择 Echo 文件夹`
3. 配置签名：`File → Project Structure → Signing Configs`
4. 选择虚拟机：Phone 或 Tablet（API 12+）

## 编译命令

在 DevEco Studio 中点击 `Run` 按钮，或使用终端：
```bash
# 在 DevEco Studio 终端中
hvigorw assembleHap -p product=default -p requiredDeviceType=tablet
```

## 开发步骤（当前阶段）

### 第6步：编译验证（当前）
- 点击 Run，观察编译错误
- 每次修复一个错误 → 重新编译 → 确认通过
- 直到 0 Error（Warning 可暂时忽略）

### 第7步：虚拟机运行验证
1. 编译通过后 App 自动安装到虚拟机
2. 手动测试：复制文字 → 切换到 Echo → 确认记录出现
3. 测试 Tab 切换、分类、搜索、设置

### 后续步骤
- 修复运行时发现的问题
- 完善图片处理功能
- 优化 UI 细节

## 故障排查

| 问题 | 检查点 |
|------|--------|
| 编译错误 | 对照 [tech-stack.md](tech-stack.md) 中的 ArkTS 限制 |
| API 不存在 | 查看编译器建议的替代 API 名称 |
| 类型不匹配 | 检查是否需要 `Number()` 转换或 await |
| 权限不足 | 检查 `module.json5` 是否声明了对应权限 |

## 参考代码

- **Example 项目**: `../Example/` — 验证过的 HarmonyOS ArkTS 代码
- **鸿蒙官方文档**: https://developer.huawei.com/consumer/cn/doc/
