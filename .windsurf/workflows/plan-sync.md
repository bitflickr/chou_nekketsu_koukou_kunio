---
description: 强制规则：所有 plan 文档必须同步至项目 plans 目录
---

# Plan 文档同步规则（强制）

**此规则为强制性规则，适用于所有 workflow 和所有对话。**

## 规则

1. **任何** plan 相关文档（包括但不限于）：
   - Windsurf plans 目录（`C:\Users\admin\.windsurf\plans\`）中生成的计划文件
   - 游戏设计文档（GDD）
   - 开发路线图
   - 数据分析文档
   - 任何以 `.md` 形式存在的规划、设计、分析文档

2. **必须同步 copy 一份**至项目的 plans 目录：
   ```
   d:\mywork\yaxuan\chou_nekketsu_koukou_kunio\plans\
   ```

3. **同步时机**：
   - 创建新 plan 文档时，立即同步
   - 更新已有 plan 文档时，立即同步更新
   - 完成任何 workflow 步骤后，检查是否有 plan 文档需要同步

4. **文件命名**：
   - 保持原文件名不变
   - 如果来源是 Windsurf plans 目录，保留原文件名（含后缀）

## 检查清单

每次操作结束前，确认：
- [ ] 所有新建的 plan 文档已 copy 至 `plans/`
- [ ] 所有修改的 plan 文档已同步更新至 `plans/`
- [ ] `plans/` 目录中的文件与源文件内容一致
