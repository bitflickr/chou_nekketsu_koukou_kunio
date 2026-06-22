---
description: 新功能开发流程
---

# 新功能开发流程

开发新功能时，按以下步骤执行：

## 步骤

1. **更新 GDD**
   - 在 `plans/game_design_document.md` 中添加或修改相关章节
   - 明确功能的设计细节、交互规则、边界条件

2. **确认数据需求**
   - 如果功能涉及角色属性、必杀技等数值，先在 `plans/original_game_data.md` 中补充数据
   - 确保数值设计与原版一致（完整复刻要求）

3. **编写代码**
   - 在 `source/scripts/` 对应目录下创建或修改脚本
   - 在 `source/scenes/` 中创建或修改场景文件
   - 遵循项目代码结构规范

4. **更新路线图**
   - 在 `plans/development_roadmap.md` 中标记相关里程碑任务的完成状态
   - 记录实际耗时与备注

5. **同步 plans 目录**
   - 遵守 `plan-sync` 强制规则，确保所有修改过的 plan 文档已同步至 `plans/`
