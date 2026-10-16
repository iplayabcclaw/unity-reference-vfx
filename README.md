# Unity Reference VFX

**中文** | [English](README.en.md)

参考图驱动的 Unity 技能特效 AI skill：从技能描述和视觉参考出发，制作参考板、拆解效果，并把轮廓、程序材质、空间关系与运动落实到 Unity 工程。

适合希望用 AI 辅助制作和迭代技能特效的 Unity 开发者、技术美术与独立游戏团队。仓库提供工作流程、专项实现参考、可复用代码和素材；使用时按目标项目的渲染管线与正式技能事件接入。

## 实现约束：禁止贴图

参考图只用于观察与拆解。运行时特效使用实际网格、网格粒子、顶点动画和不采样贴图的程序 Shader；禁止颜色图、透明图、遮罩、法线图、密度图、噪声图、Flow Map、图集、序列帧，以及用 Sprite、billboard 或图片面片替代主体。程序噪声与解析场直接计算，不烘焙为纹理再采样。

## 能做什么

- **制作参考板**：编写生图提示词，组织整体效果与关键部件的多格技术参考板，将概念参考映射到实际网格与程序材质。
- **从图片还原特效**：分析参考图、实机截图或手绘位置图，拆解轮廓、比例、负空间、明暗、纹理、层次和运动。
- **在 Unity 中实现**：按介质选择实际网格、动态曲面、网格粒子、有截面变化的条带或拖尾，处理 Shader、材质、挂点、朝向、暂停与对象池生命周期。
- **针对反馈迭代**：修正弧度、位置、厚度、遮挡、亮度和时序，保持已认可的表现稳定。
- **生成代码离线预览**：从实际网格数据与移植的材质公式生成近似图片，用于讨论造型和阶段变化。

## 安装与开始使用

### 在 Codex 中安装

在终端执行以下命令，把完整仓库放入个人技能目录（目标目录须尚不存在）：

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/iplayabcclaw/unity-reference-vfx.git \
  ~/.agents/skills/unity-reference-vfx
```

只在某个项目使用时，也可以把完整目录放到 `<项目根目录>/.agents/skills/unity-reference-vfx/`。保留 `references/`、`assets/` 和 `scripts/`，只复制 `SKILL.md` 会缺少参考资料与素材。

安装后在 Codex CLI 或 IDE 扩展中使用 `$unity-reference-vfx` 调用；如果技能未显示，重启 Codex。目录发现和调用方式参见 [OpenAI 官方技能文档](https://learn.chatgpt.com/docs/build-skills)。

### 其他支持 skill 的 AI 工具

按工具自己的技能加载方式导入完整目录，入口是 [SKILL.md](SKILL.md)。核心指令和专项参考目前以中文编写；本仓库提供中英文使用介绍。

### 使用示例

仅设计参考板：

```text
使用 $unity-reference-vfx，为青绿色护体气流编写四宫格参考板提示词。
包含整体效果、翻卷纤维、人物挂点和运动阶段，暂时只输出提示词。
```

根据图片实现：

```text
使用 $unity-reference-vfx，根据附图在当前 Unity URP 工程实现火墙特效。
保留立体火簇、中心亮芯与向上翻卷，接入现有技能事件，并说明验证范围。
```

修正已有特效：

```text
使用 $unity-reference-vfx，分析附图和当前实现的差异。
只调整斩击的弧度与腰侧挂点，保留颜色和尺寸，并给出代码离线预览。
```

提供 Unity 版本、渲染管线、目标平台、镜头、参考图和现有技能入口有助于实施；没有工程时可先完成参考素材与实施方案。

## 仓库内容

| 路径 | 内容 |
| --- | --- |
| [SKILL.md](SKILL.md) | 入口、工作流程、空间规则与交付边界 |
| [agents/openai.yaml](agents/openai.yaml) | 技能显示名称、简介与默认提示词 |
| [references/](references/) | 生图规范、还原方法、工程接入与专项代码参考 |
| [assets/procedural-flame/](assets/procedural-flame/) | 无贴图立体火焰的 Unity C# 与 URP Shader |
| [scripts/render_mesh_preview.py](scripts/render_mesh_preview.py) | 正交投影的离线网格预览器 |

## 按任务查阅

| 任务 | 参考 |
| --- | --- |
| 参考板、生图提示词与部件拆解 | [多格技术参考板](references/multi-panel-reference.md) |
| 轮廓还原、比例与分层配方 | [参考图还原](references/reference-fidelity.md) |
| 翻卷气流、护体摆放与路径卷云的几何和运动 | [翻卷气流](references/folded-airflow-reference.md) |
| 扩散尘浪、浓度和隆起波峰 | [径向震荡波](references/dust-shockwave-reference.md) |
| 地面分叉裂纹与中央碎岩 | [龟裂与碎岩](references/ground-fracture-reference.md) |
| 立体火簇、热芯与程序燃烧 | [无贴图火焰](references/procedural-flame-reference.md) |
| 材质初始化、资源绑定与装配 | [Shader 与装配](references/shader-and-assembly.md) |
| 正式事件、暂停和对象池生命周期 | [工程接入与验证](references/integration-and-validation.md) |
| 从当前实现生成近似图片 | [代码驱动的预览](references/code-image-preview.md) |

## 环境与验证范围

- **AI 环境**：阅读与分析需要能访问工程和图片的 AI 工具；实际生成或编辑图片需要宿主提供相应能力，本仓库不附带生图服务。
- **Unity**：通用流程可适配不同工程，随附 Shader 示例使用 URP；其他渲染管线需要适配。具体 Unity 版本和平台兼容性应在目标工程中验证。
- **离线预览**：需要 Python 3、NumPy 与 Pillow，以及从当前实现导出的场景 JSON 和任务专用材质适配器，输入格式见预览文档。预览器不执行 HLSL，也不模拟 Unity 光照或后处理。
- **接入边界**：视觉效果挂接现有释放、命中或持续事件；伤害、消耗、控制和 AI 决策由宿主游戏负责。
- **验证边界**：代码接入、C# 编译、Shader 导入、离线观感、实机效果和 GPU 性能分别验证，并遵守目标项目对 Editor、PlayMode 和截图的限制。
