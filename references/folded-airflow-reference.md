# 翻卷纤维气流：几何与运动参考

类型：随 skill 提供的无贴图几何参考。适用于宽面翻卷气纱、护体伴随气流和沿真实路径留下的卷云。仅复用曲面、摆放与路径采样方法，不保证复现任何旧材质的观感。

所有实现遵守 [禁止贴图约束](../SKILL.md#硬性约束禁止贴图)。本文不提供纹理或纹理采样 Shader；调用方须使用直接计算纤维、密度、柔边与明暗的程序材质，不能以透明面片图片、噪声贴图或 Flow Map 补齐。

宽面沿长度扭转，横截面边缘卷起，头尾收窄；实际网格承担轮廓和翻卷，顶点 Alpha 表达端部与横向柔边。内部纤维须按参考图实现程序场，不能把通用噪声当成已还原。下列 Paint 示例使用 `_Color`、`_Opacity`、`_Age`、`_Emission`，接入时核对实际无贴图 Shader 的属性契约。

## 1. 翻卷网格与局部摆放

```csharp
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

// Save this block as FoldedAirflowReference.cs. Unity APIs must run on the main thread.
public static class FoldedAirflowReference
{
    // Allocate once during initialization, then pass the same block on every update.
    // This replaces the renderer's property block; merge with the project's block if necessary.
    public static void Paint(MeshRenderer renderer, MaterialPropertyBlock block,
        Color tint, float opacity, float age, float emission = 1.5f)
    {
        block.Clear();
        block.SetColor("_Color", tint);
        block.SetFloat("_Opacity", Mathf.Clamp01(opacity));
        block.SetFloat("_Age", Mathf.Max(0f, age));
        block.SetFloat("_Emission", Mathf.Max(0f, emission));
        renderer.SetPropertyBlock(block);
        renderer.enabled = opacity > .001f;
    }

    public static MeshRenderer CreateVeil(Transform parent, Mesh mesh, Material material)
    {
        var child = new GameObject("Folded air veil", typeof(MeshFilter), typeof(MeshRenderer));
        child.transform.SetParent(parent, false);
        child.GetComponent<MeshFilter>().sharedMesh = mesh;
        var renderer = child.GetComponent<MeshRenderer>();
        renderer.enabled = false; // Enable only after pose and properties are ready.
        renderer.sharedMaterial = material;
        renderer.shadowCastingMode = ShadowCastingMode.Off;
        renderer.receiveShadows = false;
        return renderer;
    }

    // Original three-veil gathering pose. Root: character position/rotation, uniform height scale.
    // veils.Length must be 3; age follows the caller's visual clock.
    public static void DrawWindup(MeshRenderer[] veils, MaterialPropertyBlock block,
        float age, float life, float visibility = 1f)
    {
        life = Mathf.Max(.15f, life);
        float progress = Mathf.Clamp01(age / life);
        float alpha = Mathf.SmoothStep(0f, 1f, Mathf.Clamp01(age / .12f))
            * Mathf.Clamp01((life - age) / .16f) * visibility;
        for (int i = 0; i < 3; i++)
        {
            float side = i - 1;
            var veil = veils[i];
            veil.transform.localPosition = new Vector3(side * .34f, .25f + i * .19f, -.8f + progress * .22f);
            veil.transform.localRotation = Quaternion.Euler(-8f, -side * 12f,
                side * 24f + Mathf.Sin(age * 3f + i) * 8f);
            veil.transform.localScale = new Vector3(.65f, .7f, .85f + i * .08f);
            Paint(veil, block, i == 1 ? new Color(.76f, .96f, 1f) : new Color(.28f, .78f, .71f),
                alpha, age, 1.7f);
        }
    }

    // Original four mirrored veils; guard=true is the small shield companion,
    // guard=false is the broad step airflow. Root scale = character height (guard: height*.75).
    // For step, retain the heading captured at creation. fade comes from the actual buff/cast lifetime.
    public static void DrawSurround(MeshRenderer[] veils, MaterialPropertyBlock block,
        bool guard, float age, float fade)
    {
        for (int i = 0; i < 4; i++)
        {
            float side = i % 2 == 0 ? -1f : 1f;
            bool lower = i >= 2;
            var position = guard ? new Vector3(side * (lower ? .37f : .24f), lower ? .015f : .065f, lower ? .08f : -.14f)
                : new Vector3(side * .34f, lower ? .025f : .08f, -.31f);
            var rotation = guard ? Quaternion.Euler(lower ? -12f : -47f, side * (lower ? 63f : 24f), side * (lower ? 17f : 10f))
                : Quaternion.Euler(lower ? -5f : -12f, side * 8f, side * (6f + Mathf.Sin(age * 1.2f) * 2f));
            var scale = guard ? (lower ? new Vector3(side * .22f, .14f, .32f) : new Vector3(side * .35f, .38f, .57f))
                : new Vector3(side * (lower ? .57f : .78f), lower ? .43f : .65f, lower ? .83f : 1.05f);
            veils[i].transform.localPosition = position;
            veils[i].transform.localRotation = rotation;
            veils[i].transform.localScale = scale;
            Paint(veils[i], block, new Color(.4f, .91f, .90f), fade * (lower ? .30f : .69f), age, 1.8f);
        }
    }
        public static Mesh BuildFoldedMesh()
        {
            const int rows = 54, columns = 16;
            var vertices = new List<Vector3>(); var uv = new List<Vector2>();
            var colors = new List<Color>(); var triangles = new List<int>();
            for (int row = 0; row <= rows; row++)
                for (int col = 0; col <= columns; col++)
                {
                    float u = row / (float)rows, v = col / (float)columns * 2f - 1f;
                    float envelope = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * u)), .65f);
                    float width = (.12f + .24f * envelope) * Mathf.Pow(1f - u, .36f);
                    // A broad folded cloth section which rolls through more than half a turn:
                    // open mouths, raised crests and loose hooked edges survive without textures.
                    float roll = u * Mathf.PI * 3.4f + .40f * Mathf.Sin(u * 14f);
                    float section = v * width;
                    float curl = Mathf.Pow(Mathf.Abs(v), 3f) * envelope * .17f;
                    float x = section * Mathf.Cos(roll) + .055f * Mathf.Sin(u * 11f);
                    float y = .04f + u * .46f + section * Mathf.Sin(roll) + curl;
                    float z = u * 1.35f + Mathf.Sin(v * 3.3f + u * 15f) * envelope * .04f;
                    vertices.Add(new Vector3(x, y, z)); uv.Add(new Vector2(u, (v + 1f) * .5f));
                    float edge = Mathf.Pow(Mathf.Abs(v), 5f);
                    float shade = .62f + edge * .38f;
                    float alpha = Mathf.Pow(Mathf.Max(0f, Mathf.Sin(Mathf.PI * u)), .45f)
                        * Mathf.Clamp01((1f - Mathf.Abs(v)) * 8f);
                    colors.Add(new Color(shade, shade, shade, alpha));
                }
            for (int row = 0; row < rows; row++)
                for (int col = 0; col < columns; col++)
                {
                    int a = row * (columns + 1) + col, b = a + columns + 1;
                    triangles.Add(a); triangles.Add(b); triangles.Add(a + 1);
                    triangles.Add(a + 1); triangles.Add(b); triangles.Add(b + 1);
                }
            var mesh = new Mesh { name = "Shared folded fibrous airflow", hideFlags = HideFlags.HideAndDontSave };
            mesh.SetVertices(vertices); mesh.SetUVs(0, uv); mesh.SetColors(colors); mesh.SetTriangles(triangles, 0);
            mesh.RecalculateNormals(); mesh.RecalculateBounds();
            return mesh;
        }

}
```

## 2. 沿真实路径生成卷云

```csharp
using System;
using UnityEngine;
using UnityEngine.Rendering;

// Save as CloudAirflowReference.cs. Caller owns root/material; this class owns its dynamic mesh.
// Feed collision-resolved world positions with the desired small ground offset already applied.
public sealed class CloudAirflowReference : IDisposable
{
    private const int Samples = 40, Rows = 13, Layers = 3;
    private const float Lifetime = .72f;
    private readonly Vector3[] _points = new Vector3[Samples];
    private readonly float[] _times = new float[Samples];
    private readonly MaterialPropertyBlock _properties = new MaterialPropertyBlock();
    private Mesh _mesh;
    private MeshRenderer _renderer;
    private Vector3[] _vertices;
    private Vector2[] _uv;
    private Color[] _colors;
    private int _count;
    private float _age, _lastSample;
    public bool Finished => _count > 0 && _age - _lastSample > Lifetime;

    public void AddPoint(Vector3 world)
    {
        _lastSample = _age;
        if (_count > 0 && (world - _points[_count - 1]).sqrMagnitude < .00000001f) return;
        if (_count == Samples)
        {
            for (int i = 1; i < Samples; i++)
            { _points[i - 1] = _points[i]; _times[i - 1] = _times[i]; }
            _count--;
        }
        _points[_count] = world; _times[_count] = _age; _count++;
    }

    // Use only the project's actual visual delta; pass zero while frozen.
    public void Advance(float visualDelta) { _age += Mathf.Max(0f, visualDelta); }
    public void Reset()
    {
        _age = _lastSample = 0f; _count = 0;
        _renderer.enabled = false;
    }
        public CloudAirflowReference(GameObject root, Material cloudMaterial)
        {
            if (root == null || cloudMaterial == null)
                throw new ArgumentException("Assign a dedicated root and the cloud material.");
            var material = cloudMaterial;
            root.transform.SetParent(null, true);
            root.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
            root.transform.localScale = Vector3.one;
            _mesh = new Mesh { name = "流云侧移·三层卷起宽面", hideFlags = HideFlags.HideAndDontSave };
            _mesh.MarkDynamic();
            var filter = root.GetComponent<MeshFilter>();
            if (filter == null) filter = root.AddComponent<MeshFilter>();
            filter.sharedMesh = _mesh;
            _renderer = root.GetComponent<MeshRenderer>();
            if (_renderer == null) _renderer = root.AddComponent<MeshRenderer>();
            _renderer.sharedMaterial = material;
            _renderer.enabled = false;
            _renderer.shadowCastingMode = ShadowCastingMode.Off; _renderer.receiveShadows = false;
            _renderer.sortingOrder = 10;
            int count = Samples * Rows * Layers;
            _vertices = new Vector3[count]; _uv = new Vector2[count]; _colors = new Color[count];
            var normals = new Vector3[count];
            for (int i = 0; i < count; i++) normals[i] = Vector3.up;
            var indices = new int[(Samples - 1) * (Rows - 1) * Layers * 6];
            int cursor = 0;
            for (int layer = 0; layer < Layers; layer++)
                for (int sample = 0; sample < Samples - 1; sample++)
                    for (int row = 0; row < Rows - 1; row++)
                    {
                        int a = layer * Samples * Rows + sample * Rows + row;
                        indices[cursor++] = a; indices[cursor++] = a + Rows; indices[cursor++] = a + 1;
                        indices[cursor++] = a + 1; indices[cursor++] = a + Rows; indices[cursor++] = a + Rows + 1;
                    }
            _mesh.vertices = _vertices; _mesh.normals = normals; _mesh.triangles = indices;
        }

        public void Draw(float h, Vector3 fallbackForward, float visibility = 1f, bool lowEffects = false)
        {
            if (_count < 2) { _renderer.enabled = false; return; }
            if (h <= 0f) throw new ArgumentOutOfRangeException(nameof(h));
            for (int layer = 0; layer < Layers; layer++)
            {
                float distance = 0f;
                for (int sample = 0; sample < Samples; sample++)
                {
                    int current = Mathf.Min(sample, _count - 1);
                    if (sample > 0 && sample < _count) distance += Vector3.Distance(_points[sample], _points[sample - 1]);
                    var tangent = _points[Mathf.Min(current + 1, _count - 1)] - _points[Mathf.Max(0, current - 1)];
                    tangent.y = 0f;
                    if (tangent.sqrMagnitude < .00001f)
                    { tangent = fallbackForward; tangent.y = 0f; }
                    if (tangent.sqrMagnitude < .00001f) tangent = Vector3.forward;
                    tangent.Normalize();
                    var side = Vector3.Cross(Vector3.up, tangent);
                    float life = Mathf.Clamp01((_age - _times[current]) / Lifetime);
                    float fade = sample < _count ? Mathf.Pow(1f - life, 1.3f) * visibility : 0f;
                    if (sample == 0 || sample == _count - 1) fade *= .2f;
                    if (lowEffects && layer == 2) fade = 0f;
                    for (int row = 0; row < Rows; row++)
                    {
                        float v = row / (float)(Rows - 1), q = v * 2f - 1f;
                        float arch = Mathf.Sin(v * Mathf.PI);
                        float phase = distance * 4.6f - _age * 3.2f + layer * 1.7f;
                        // Each transverse section rolls over instead of being a flat ribbon with a bright outline.
                        float curl = Mathf.Pow(Mathf.Abs(q), 1.4f) * 4.8f + .30f * Mathf.Sin(phase);
                        float width = h * (.33f + layer * .11f) * (.8f + life * .4f);
                        float lateral = q * width + Mathf.Sign(q) * Mathf.Sin(curl) * width * .23f;
                        float rise = h * (.07f + layer * .07f) + (1f - Mathf.Cos(curl)) * h * .115f;
                        rise += arch * h * .045f * Mathf.Sin(phase + v * 6f);
                        var vertex = _points[current] + side * lateral + Vector3.up * rise;
                        vertex -= tangent * h * layer * .075f;
                        int index = layer * Samples * Rows + sample * Rows + row;
                        _vertices[index] = vertex;
                        _uv[index] = new Vector2(distance / h + layer * .31f, v);
                        float fold = .55f + .45f * Mathf.Clamp01(.5f + .5f * Mathf.Sin(curl));
                        var color = Color.Lerp(new Color(.14f, .43f, .46f), new Color(.61f, .98f, .94f), fold);
                        color.a = fade * Mathf.Pow(Mathf.Clamp01(arch), .55f) * (layer == 1 ? .8f : .62f);
                        _colors[index] = color;
                    }
                }
            }
            _mesh.vertices = _vertices; _mesh.uv = _uv; _mesh.colors = _colors;
            _mesh.RecalculateBounds();
            FoldedAirflowReference.Paint(_renderer, _properties, Color.white, 1f, _age, 1.8f);
        }


    public void Dispose()
    {
        if (_renderer != null) _renderer.enabled = false;
        if (_mesh != null) UnityEngine.Object.Destroy(_mesh);
        _mesh = null;
    }
}
```

## 3. 接入与成本边界

在目标工程正式事件中创建或租借根物体，初始化完成后才绘制。把上述代码块分别保存成对应文件；主线程创建一次网格、材质与属性块，并复用它们。共享网格与材质由所有者统一释放；根物体回池时重置年龄、路径与显隐，禁止每次绘制重建资源。

蓄势示例：根物体放到施法者位置，朝向取角色朝向，统一缩放为角色高度；创建三片共用网格／材质的 veil，按真实蓄势时长调用 `DrawWindup`。护体示例创建四片 veil，使用 `DrawSurround`；原护体渐入为 0.24 秒，短盾总寿命 1.2 秒／最后 0.3 秒淡出，步法最后 0.22 秒淡出，这些是参考视觉参数，接入时服从真实技能生命周期。负 X 缩放用来镜像两侧卷纱，Shader 双面绘制。

路径示例：使用云材质创建 `CloudAirflowReference`，先加入真实位移起点与终点，后续位移完成后再 `AddPoint`。每帧先按项目时钟 `Advance` 再 `Draw`；`Finished` 时停止绘制并回收。取消或来源失效由正式调用方立即清理。根物体保持世界原点、单位缩放，不挂在移动角色下面。高度单位 `h` 对应人物实际高度；原项目采样点位于地面上方 0.08 世界单位，移植时按项目单位调整。暂停时年龄不推进，Shader 不读取 `_Time`。隐身／变形的可见度由调用方传入，不复制原项目的状态判断。

复用这些几何和运动公式时仍须核对当前参考的轮廓与比例，不自动简化成旋转光带。性能核对：

- 静态翻卷网格为 **935 顶点、1728 三角形**，构建时的循环与三角函数仅执行一次；每帧只更新少数片的姿态与属性。
- 原路径卷云上限 **1560 顶点、2808 三角形**，每帧 CPU 重建顶点与颜色并上传；其循环与三角函数确实有持续成本，不能称为零成本。低特效示例隐藏第三层只是视觉裁减，仍然遍历并提交该层；要真实省计算与几何，需另做减少层数的网格版本并验证差异。
- 多片双面透明气纱会叠加屏幕覆盖与 overdraw，人数多时先测透明重叠、CPU 网格更新和上传成本。先复用资源、限制实例与路径采样，再考虑降低网格分段；程序材质成本与卷曲几何成本分别评估。

这些是提取的几何与运动参考代码，不代表在其他工程里已完成 Shader 导入或实机验收。正式游戏代码没有因添加本参考而改变。
