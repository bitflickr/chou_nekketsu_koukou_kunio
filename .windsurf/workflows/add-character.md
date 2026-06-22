---
description: 添加新角色或队伍的流程
---

# 添加角色/队伍流程

添加新角色或新队伍时，按以下步骤执行：

## 步骤

1. **补充原版数据**
   - 在 `plans/original_game_data.md` 中添加角色属性（HP/ATK/DEF/SPD/JMP）
   - 添加必杀技信息（名称、触发条件、轨迹描述、伤害倍率）
   - 如果是新队伍，添加队伍信息和世界杯对战顺序

2. **注册角色数据**
   - 在 `source/scripts/global/team_data.gd` 中注册新角色/队伍的数据
   - 确保属性值与 `original_game_data.md` 中的数据一致

3. **创建精灵资源**
   - 在 `source/assets/sprites/` 下添加角色精灵表
   - 包含：站立、行走、跳跃、投球、接球、被击中、必杀技动画帧

4. **实现必杀技**
   - 如果角色有独特的必杀技轨迹，在 `source/scripts/ball/special_throws.gd` 中添加对应逻辑

5. **更新 GDD**
   - 在 `plans/game_design_document.md` 中更新角色系统相关章节

6. **同步 plans 目录**
   - 遵守 `plan-sync` 强制规则
