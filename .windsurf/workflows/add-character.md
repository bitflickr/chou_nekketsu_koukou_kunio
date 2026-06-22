---
description: 添加新角色或队伍的流程
---

# 添加角色/队伍流程

添加新角色或新队伍时，按以下步骤执行：

## 步骤

1. **创建 Issue**
   - 在 GitHub Issues 中创建角色/队伍添加 Issue（使用 Feature 模板）
   - 打上标签：`type:feature` + `area:character` + `P*`，关联对应 Milestone

2. **补充原版数据**
   - 在 `plans/original_game_data.md` 中添加角色属性（HP/ATK/DEF/SPD/JMP）
   - 添加必杀技信息（名称、触发条件、轨迹描述、伤害倍率）
   - 如果是新队伍，添加队伍信息和世界杯对战顺序

3. **注册角色数据**
   - 在 `source/scripts/global/team_data.gd` 中注册新角色/队伍的数据
   - 确保属性值与 `original_game_data.md` 中的数据一致

4. **创建精灵资源**
   - 在 `source/assets/sprites/` 下添加角色精灵表
   - 包含：站立、行走、跳跃、投球、接球、被击中、必杀技动画帧

5. **实现必杀技**
   - 如果角色有独特的必杀技轨迹，在 `source/scripts/ball/special_throws.gd` 中添加对应逻辑

6. **提交代码**
   - commit message 中引用 Issue：`Fixes #<issue_number>`（自动关闭）或 `Ref #<issue_number>`（部分完成）

7. **更新 GDD**
   - 在 `plans/game_design_document.md` 中更新角色系统相关章节

8. **同步 plans 目录**
   - 遵守 `plan-sync` 强制规则
