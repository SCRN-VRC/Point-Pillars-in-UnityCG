#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEngine.UI;

[ExecuteInEditMode]
public class BakeTestData : EditorWindow
{
    public TextAsset source0;
    string SavePath1;

    [MenuItem("Tools/SCRN/Bake BakeTestData")]
    static void Init()
    {
        var window = GetWindowWithRect<BakeTestData>(new Rect(0, 0, 400, 250));
        window.Show();
    }
    
    void OnGUI()
    {
        GUILayout.Label("Bake BakeTestData", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical();
        source0 = (TextAsset) EditorGUILayout.ObjectField("Bake BakeTestData (.bytes):", source0, typeof(TextAsset), false);
        EditorGUILayout.EndVertical();

        if (GUILayout.Button("Bake!") && source0 != null) {
            string path = AssetDatabase.GetAssetPath(source0);
            int fileDir = path.LastIndexOf("/");
            SavePath1 = path.Substring(0, fileDir) + "/000009.asset";
            OnGenerateTexture();
        }
    }

    void OnGenerateTexture()
    {
        const int width = 512;
        const int height = 512;

        Texture2D tex = new Texture2D(width, height, TextureFormat.RGBAFloat, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Point;
        tex.anisoLevel = 1;

        ExtractFromBin(tex, source0);
        AssetDatabase.CreateAsset(tex, SavePath1);
        AssetDatabase.SaveAssets();

        ShowNotification(new GUIContent("Done"));
    }

    void writeBlock(Texture2D tex, BinaryReader br0, int totalFloats, int destX, int destY, int width)
    {
        //Debug.Log("Writing " + totalFloats + " at " + destX + ", " + destY);
        for (int i = 0; i < totalFloats; i++)
        {
            int x = i % width;
            int y = i / width;
            tex.SetPixel(x + destX, y + destY,
                new Color(br0.ReadSingle(), br0.ReadSingle(),
                    br0.ReadSingle(), br0.ReadSingle())); //br0.ReadSingle()
        }
    }

    void ExtractFromBin(Texture2D tex, TextAsset srcIn0)
    {
        Stream s0 = new MemoryStream(srcIn0.bytes);
        BinaryReader br0 = new BinaryReader(s0);

        // First texture
        writeBlock(tex, br0, 115275, 0, 0, 512);
    }
}

#endif