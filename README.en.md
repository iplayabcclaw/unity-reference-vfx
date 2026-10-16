# Unity Reference VFX

[中文](README.md) | **English**

An AI skill for reference-driven Unity ability effects: create reference boards, break down visual targets, and translate their silhouettes, procedural materials, spatial relationships, and motion into a Unity project.

Designed for Unity developers, technical artists, and indie teams using AI to build and refine ability VFX. This repository includes workflow instructions, implementation references, reusable code, and assets. Adapt them to your project's rendering pipeline and actual ability events.

## Implementation constraint: no textures

Reference images are for observation and analysis only. Runtime VFX use actual meshes, mesh particles, vertex animation, and procedural shaders without texture sampling. Color, alpha, mask, normal, density, noise, flow-map, atlas, and flipbook textures are prohibited, as are sprites, billboards, or image planes used to replace effect geometry. Compute procedural noise and analytical fields directly instead of baking them into sampled textures.

## What it does

- **Create reference boards**: write image-generation prompts and arrange overall effects and key components into technical panels, mapping concept references to actual meshes and procedural materials.
- **Reconstruct effects from images**: analyze reference art, gameplay screenshots, or placement sketches for silhouette, proportions, negative space, lighting, textures, layers, and motion.
- **Implement in Unity**: choose actual meshes, dynamic surfaces, mesh particles, or ribbons and trails with varying cross-sections for each medium; handle shaders, materials, attachment points, orientation, pausing, and pooling lifecycles.
- **Iterate on specific feedback**: refine curvature, placement, thickness, occlusion, brightness, and timing while preserving approved features.
- **Produce offline code previews**: generate approximate images from actual mesh data and ported material formulas to discuss shape and animation stages.

## Installation and quick start

### Install in Codex

Run the following commands in a terminal to place the complete repository in your personal skills directory. The destination directory must not already exist.

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/iplayabcclaw/unity-reference-vfx.git \
  ~/.agents/skills/unity-reference-vfx
```

For use in a single project, place the complete directory at `<project-root>/.agents/skills/unity-reference-vfx/` instead. Keep `references/`, `assets/`, and `scripts/` together; copying only `SKILL.md` leaves out supporting references and assets.

Invoke `$unity-reference-vfx` in Codex CLI or the IDE extension. If the skill does not appear, restart Codex. See the [official OpenAI skills documentation](https://learn.chatgpt.com/docs/build-skills) for discovery and invocation details.

### Other AI tools with skill support

Import the complete directory using your tool's skill-loading mechanism, with [SKILL.md](SKILL.md) as the entry point. Core instructions and specialized references are currently written in Chinese; this repository provides both Chinese and English introductory documentation.

### Example prompts

Design a reference board:

```text
Use $unity-reference-vfx to write a four-panel reference-board prompt for
teal protective airflow. Include the overall effect, curled fibers,
character attachment points, and motion stages. Output only the prompt for now.
```

Implement from an image:

```text
Use $unity-reference-vfx to implement the attached fire-wall reference in
this Unity URP project. Preserve the three-dimensional flame clusters,
bright core, and upward curling motion. Integrate with existing ability
events and explain what has been validated.
```

Refine an existing effect:

```text
Use $unity-reference-vfx to compare the attached reference with the current
implementation. Adjust only the slash curvature and waist attachment point,
preserve its colors and size, and provide an offline code preview.
```

Providing the Unity version, rendering pipeline, target platform, camera, reference images, and existing ability entry points helps implementation. Without a project, start with reference assets and an implementation plan.

## Repository contents

| Path | Contents |
| --- | --- |
| [SKILL.md](SKILL.md) | Entry point, workflow, spatial rules, and delivery boundaries |
| [agents/openai.yaml](agents/openai.yaml) | Display name, summary, and default prompt |
| [references/](references/) | Image prompting, reconstruction, integration, and specialized code references |
| [assets/procedural-flame/](assets/procedural-flame/) | Unity C# and URP shader for texture-free three-dimensional flames |
| [scripts/render_mesh_preview.py](scripts/render_mesh_preview.py) | Offline orthographic mesh renderer |

## Find the right reference

| Task | Reference |
| --- | --- |
| Reference boards, image prompts, and component breakdowns | [Multi-panel technical boards](references/multi-panel-reference.md) |
| Silhouette fidelity, proportions, and layer recipes | [Reference fidelity](references/reference-fidelity.md) |
| Geometry and motion for folded airflow, protective arrangements, and trailing clouds | [Folded airflow](references/folded-airflow-reference.md) |
| Expanding dust waves, density, and raised crests | [Radial shockwaves](references/dust-shockwave-reference.md) |
| Branching ground cracks and central rock fragments | [Ground fractures](references/ground-fracture-reference.md) |
| Three-dimensional flame clusters, hot cores, and procedural burning | [Texture-free flames](references/procedural-flame-reference.md) |
| Material initialization, resource binding, and assembly | [Shaders and assembly](references/shader-and-assembly.md) |
| Actual events, pausing, and pooling lifecycles | [Integration and validation](references/integration-and-validation.md) |
| Approximate images derived from the current implementation | [Code-driven previews](references/code-image-preview.md) |

## Requirements and validation scope

- **AI environment**: analysis requires tools that can access your project and images. Image generation or editing requires those capabilities from the host; this repository does not include an image-generation service.
- **Unity**: the general workflow can be adapted to different projects. Bundled shader examples target URP; other rendering pipelines require adaptation. Validate Unity-version and platform compatibility in your target project.
- **Offline previews**: require Python 3, NumPy, Pillow, scene JSON exported from the current implementation, and a task-specific material adapter. The preview reference documents the input format. The renderer does not execute HLSL or simulate Unity lighting or post-processing.
- **Integration boundaries**: visuals attach to existing cast, hit, or ongoing-effect events. The host game owns damage, costs, crowd control, and AI decisions.
- **Validation boundaries**: assess code integration, C# compilation, shader import, offline appearance, in-game visuals, and GPU performance separately. Follow the target project's restrictions on the Editor, PlayMode, and screenshots.
