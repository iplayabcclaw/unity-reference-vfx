using UnityEngine;
using UnityEngine.Rendering;

namespace UnityVfxReference
{
    // Budgeted rooted lobes and shedding wisps retain closed circular cross sections.
    // The host's paused clock drives continuous geometry and analytic combustion.
    public static class ProceduralBurningFlame
    {
        private static readonly Mesh[] Volumes = new Mesh[2];
        public const int Ground = 1, Smoke = 2, Ember = 3;
        private static readonly Material[] Materials = new Material[8];
        private static MaterialPropertyBlock _properties;

        public static Mesh GetVolume(bool lowEffects = false)
        {
            int quality = lowEffects ? 1 : 0;
            if (Volumes[quality] == null)
                Volumes[quality] = quality == 0 ? BuildVolume(16, 8, 4, 2) : BuildVolume(12, 6, 3, 1);
            return Volumes[quality];
        }

        private static Mesh BuildVolume(int rows, int columns, int roots, int wisps)
        {
            int tongues = roots + wisps;
            int stride = (rows + 1) * (columns + 1);
            var vertices = new Vector3[stride * tongues];
            var uv = new Vector2[vertices.Length];
            var channels = new Vector2[vertices.Length];
            var colors = new Color[vertices.Length];
            var triangles = new int[rows * columns * 6 * tongues];
            for (int tongue = 0; tongue < tongues; tongue++)
            for (int y = 0; y <= rows; y++)
            for (int x = 0; x <= columns; x++)
            {
                int n = tongue * stride + y * (columns + 1) + x;
                float u = x / (float)columns, v = y / (float)rows;
                float radius = Mathf.Pow(1f - v, .72f) * .18f * Mathf.SmoothStep(0f, 1f, v / .06f);
                float angle = u * Mathf.PI * 2f;
                vertices[n] = new Vector3(Mathf.Cos(angle) * radius, v, Mathf.Sin(angle) * radius);
                uv[n] = new Vector2(u, v);
                // Preserve shedding IDs understood by the shader, independently of quality.
                channels[n] = new Vector2(tongue < roots ? tongue : 6 + tongue - roots, tongue >= roots ? 1f : 0f);
                colors[n] = Color.white;
                if (x == columns || y == rows) continue;
                int t = ((tongue * rows + y) * columns + x) * 6;
                triangles[t] = n; triangles[t + 1] = n + columns + 1; triangles[t + 2] = n + 1;
                triangles[t + 3] = n + 1; triangles[t + 4] = n + columns + 1; triangles[t + 5] = n + columns + 2;
            }
            var volume = new Mesh { name = "立体闭合卷焰与脱离火丝 " + rows, hideFlags = HideFlags.HideAndDontSave };
            volume.vertices = vertices; volume.uv = uv; volume.uv2 = channels;
            volume.colors = colors; volume.triangles = triangles;
            // Includes the shader's widest curl and the full shedding trajectory.
            volume.bounds = new Bounds(new Vector3(0f, .72f, 0f), new Vector3(1.8f, 1.85f, 1.8f));
            return volume;
        }

        public static Material GetMaterial(bool grave, int medium = 0)
        {
            int index = (grave ? 4 : 0) + medium;
            if (Materials[index] != null) return Materials[index];
            var shader = Resources.Load<Shader>("Shaders/ProceduralBurningFlame");
            if (shader == null)
                throw new System.InvalidOperationException("持续燃烧缺少 BurningFlame 程序 Shader。");
            var material = new Material(shader) { name = grave ? "墓火翻卷燃烧" : "火墙翻卷燃烧", hideFlags = HideFlags.HideAndDontSave };
            material.SetFloat("_Grave", grave ? 1f : 0f);
            material.SetFloat("_Medium", medium);
            material.SetFloat("_Cull", medium == 0 ? 2f : 0f);
            return Materials[index] = material;
        }

        public static MeshRenderer Create(Transform parent, bool lowEffects = false)
        {
            var go = new GameObject("错峰翻卷火簇", typeof(MeshFilter), typeof(MeshRenderer));
            go.layer = parent.gameObject.layer; go.transform.SetParent(parent, false);
            go.GetComponent<MeshFilter>().sharedMesh = GetVolume(lowEffects);
            var renderer = go.GetComponent<MeshRenderer>();
            renderer.shadowCastingMode = ShadowCastingMode.Off; renderer.receiveShadows = false;
            renderer.enabled = false;
            return renderer;
        }

        public static void RefreshMesh(MeshRenderer renderer, bool lowEffects = false)
        {
            renderer.GetComponent<MeshFilter>().sharedMesh = GetVolume(lowEffects);
        }

        public static void Paint(Renderer renderer, float clock, float phase, float opacity, float heat = 1f)
        {
            if (_properties == null) _properties = new MaterialPropertyBlock();
            _properties.Clear();
            _properties.SetFloat("_LocalClock", clock); _properties.SetFloat("_Phase", phase);
            _properties.SetFloat("_Opacity", opacity); _properties.SetFloat("_Heat", heat);
            renderer.SetPropertyBlock(_properties);
        }

        // Call once all consumers have stopped; individual plumes do not own these caches.
        public static void ReleaseSharedResources()
        {
            for (int i = 0; i < Volumes.Length; i++)
            {
                if (Volumes[i] != null) Object.Destroy(Volumes[i]);
                Volumes[i] = null;
            }
            for (int i = 0; i < Materials.Length; i++)
            {
                if (Materials[i] != null) Object.Destroy(Materials[i]);
                Materials[i] = null;
            }
            _properties = null;
        }

    }
}
