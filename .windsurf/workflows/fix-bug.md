---
description: Bug 修复流程
---

# Bug 修复流程

修复 Bug 时，按以下步骤执行：

## 步骤

1. **记录问题**
   - 在 GitHub Issues 中创建 Bug 报告（使用 Bug 模板）
   - 打上对应标签（`type:bug` + `area:*` + `P*`）并关联 Milestone
   - 明确 Bug 的表现、复现步骤、预期行为与实际行为

2. **定位根因**
   - 优先从上游（数据/逻辑）定位，而非下游（表现/UI）
   - 使用日志和断点缩小范围
   - 参考 `plans/original_game_data.md` 确认原版行为是否一致

3. **最小修复**
   - 优先单行修复，避免过度工程
   - 不删除或弱化已有测试
   - 修改范围尽可能小，避免引入新问题

4. **验证**
   - 确认 Bug 已修复
   - 确认未引入回归问题
   - 在 Godot 编辑器中运行测试场景验证

5. **提交代码**
   - commit message 中引用 Issue：`Fixes #<issue_number>`（自动关闭 Issue）
   - 如果只是部分修复，使用 `Ref #<issue_number>`

6. **更新文档（如需要）**
   - 如果 Bug 涉及设计问题，更新 `plans/game_design_document.md`
   - 遵守 `plan-sync` 强制规则
