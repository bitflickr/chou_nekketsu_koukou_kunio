# SP-M00：项目搭建

| 属性 | 值 |
|------|------|
| 里程碑 | M0 |
| 优先级层级 | L0 🔴 阻塞级 |
| 前置依赖 | 无 |
| 后续解锁 | M1（角色移动）、M2（球物理） |
| 预估工期 | 1 天 |
| 故事点数 | 6 |
| 关联风险 | RISK-05（统一输入管理层）、RISK-10（分辨率适配策略）、RISK-14（版本控制配置） |

---

## 故事点列表

| ID | 标题 | 描述 | 依赖 | 估时 | 状态 |
|----|------|------|------|------|------|
| SP-M00.1 | 创建 Godot 4 项目 | 创建 Godot 4 项目，配置 `project.godot`，设置项目名称和基础信息 | 无 | 0.5h | ⬜ |
| SP-M00.2 | 建立目录结构 | 创建 `scenes/`、`scripts/`（含 global/character/ball/court/ui 子目录）、`assets/`（含 sprites/audio/fonts）标准目录结构 | SP-M00.1 | 0.5h | ⬜ |
| SP-M00.3 | 配置项目渲染设置 | 设置分辨率 256×240、像素完美渲染（`texture_filter: Nearest`）、横屏锁定、stretch_mode=viewport、stretch_aspect=keep | SP-M00.1 | 1h | ⬜ |
| SP-M00.4 | 创建全局常量脚本 | 创建 `constants.gd` 并注册为 AutoLoad，定义场地尺寸、物理参数、伤害公式常量等全局数值 | SP-M00.2 | 1h | ⬜ |
| SP-M00.5 | 创建基础球场场景 | 创建 `court.tscn` 空白球场场景，包含基础 Node2D 层级结构（背景层、角色层、球层、UI层） | SP-M00.2 | 1h | ⬜ |
| SP-M00.6 | 配置导出预设 | 配置 Android 和 iOS 导出预设（`export_presets.cfg`），设置包名、最低版本、签名占位 | SP-M00.3 | 1h | ⬜ |

---

## 验收标准

- [ ] 项目可在 Godot 4 编辑器中正常打开
- [ ] 运行后显示 256×240 空白球场画面，像素无模糊
- [ ] 横屏显示，等比缩放无拉伸
- [ ] `constants.gd` 可通过 AutoLoad 全局访问
- [ ] Android/iOS 导出预设已创建（不要求实际构建成功）
- [ ] `.gitignore` 已配置（忽略 `.godot/`、`*.import` 等）

---

## 技术要点

- **分辨率策略**（关联 RISK-10）：
  - `window/size/viewport_width = 256`
  - `window/size/viewport_height = 240`
  - `window/stretch/mode = "viewport"`
  - `window/stretch/aspect = "keep"`
  - `rendering/textures/canvas_textures/default_texture_filter = 0`（Nearest）

- **目录结构参考**：
  ```
  source/
    project.godot
    scenes/
    scripts/global/、character/、ball/、court/、ui/
    assets/sprites/、audio/、fonts/
    export_presets.cfg
  ```

---

## 变更日志

| 日期 | 变更 |
|------|------|
| 2026-06-22 | 初始创建 |
