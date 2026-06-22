---
trigger: always_on
---

# 引擎版本强制规范

**此规则为强制性规则，适用于所有 workflow 和所有对话。**

## 唯一指定版本

- 本项目全团队统一使用 **Godot 4.7**（主版本号锁定 `4.7`，不限制具体补丁/构建号）。
- 严禁使用其他主版本（如 4.3 / 4.6 / 5.x）打开或保存 `source/project.godot`，以免：
  - `config/features` 被自动改写
  - `.tscn` / `.tres` / `.import` 等资源格式发生版本漂移导致团队 diff 冲突

## 配置约束

- `source/project.godot` 中 `config/features` 必须包含 `"4.7"`。
- 新增/修改文档涉及引擎版本时，统一写作 **Godot 4.7**。
- CI / 导出构建若引入，亦须固定为 Godot 4.7。

## 校验

- 提交前确认 `config/features=PackedStringArray("4.7", ...)`。
- 若发现版本不符，先恢复为 4.7 再提交。
