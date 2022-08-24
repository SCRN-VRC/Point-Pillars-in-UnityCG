#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using UnityEngine.UI;

[ExecuteInEditMode]
public class BakePointPillar : EditorWindow
{
    public TextAsset source0;
    public TextAsset source1;
    string SavePath1;

    [MenuItem("Tools/SCRN/Bake PointPillar Weights")]
    static void Init()
    {
        var window = GetWindowWithRect<BakePointPillar>(new Rect(0, 0, 400, 250));
        window.Show();
    }
    
    void OnGUI()
    {
        GUILayout.Label("Bake PointPillar", EditorStyles.boldLabel);
        EditorGUILayout.BeginVertical();
        source0 = (TextAsset) EditorGUILayout.ObjectField("Weights (.bytes):", source0, typeof(TextAsset), false);
        source1 = (TextAsset) EditorGUILayout.ObjectField("Rolling Mean/Variance (.bytes):", source1, typeof(TextAsset), false);
        EditorGUILayout.EndVertical();

        if (GUILayout.Button("Bake!") && source0 != null && source1 != null) {
            string path = AssetDatabase.GetAssetPath(source0);
            int fileDir = path.LastIndexOf("/");
            SavePath1 = path.Substring(0, fileDir) + "/pillar.asset";
            OnGenerateTexture();
        }
    }

    void OnGenerateTexture()
    {
        const int width = 2880;
        const int height = 2048;

        Texture2D tex = new Texture2D(width, height, TextureFormat.RFloat, false);
        tex.wrapMode = TextureWrapMode.Clamp;
        tex.filterMode = FilterMode.Point;
        tex.anisoLevel = 1;

        ExtractFromBin(tex, source0, source1);
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
                new Color(br0.ReadSingle(), 0, 0, 0)); //br0.ReadSingle()
        }
    }

    void ExtractFromBin(Texture2D tex, TextAsset srcIn0, TextAsset srcIn1)
    {
        Stream s0 = new MemoryStream(srcIn0.bytes);
        BinaryReader br0 = new BinaryReader(s0);
        Stream s1 = new MemoryStream(srcIn1.bytes);
        BinaryReader br1 = new BinaryReader(s1);

        writeBlock(tex, br0, 576, 2432, 1536, 9); //const0
        writeBlock(tex, br0, 64, 2816, 1617, 64); //const1
        writeBlock(tex, br0, 64, 2816, 1618, 64); //const2
        writeBlock(tex, br0, 36864, 2304, 1472, 576); //const3
        writeBlock(tex, br0, 64, 2816, 1627, 64); //const4
        writeBlock(tex, br0, 64, 2816, 1626, 64); //const5
        writeBlock(tex, br0, 36864, 2304, 1280, 576); //const6
        writeBlock(tex, br0, 64, 2816, 1625, 64); //const7
        writeBlock(tex, br0, 64, 2816, 1624, 64); //const8
        writeBlock(tex, br0, 36864, 2304, 1408, 576); //const9
        writeBlock(tex, br0, 64, 2816, 1623, 64); //const10
        writeBlock(tex, br0, 64, 2816, 1622, 64); //const11
        writeBlock(tex, br0, 36864, 2304, 1344, 576); //const12
        writeBlock(tex, br0, 64, 2816, 1621, 64); //const13
        writeBlock(tex, br0, 64, 2816, 1620, 64); //const14
        writeBlock(tex, br0, 73728, 2304, 1024, 576); //const15
        writeBlock(tex, br0, 128, 2304, 1624, 128); //const16
        writeBlock(tex, br0, 128, 2688, 1623, 128); //const17
        writeBlock(tex, br0, 147456, 1152, 1408, 1152); //const18
        writeBlock(tex, br0, 128, 2560, 1623, 128); //const19
        writeBlock(tex, br0, 128, 2432, 1623, 128); //const20
        writeBlock(tex, br0, 147456, 0, 1664, 1152); //const21
        writeBlock(tex, br0, 128, 2560, 1622, 128); //const22
        writeBlock(tex, br0, 128, 2688, 1621, 128); //const23
        writeBlock(tex, br0, 147456, 1152, 1280, 1152); //const24
        writeBlock(tex, br0, 128, 2304, 1621, 128); //const25
        writeBlock(tex, br0, 128, 2688, 1620, 128); //const26
        writeBlock(tex, br0, 147456, 1152, 1536, 1152); //const27
        writeBlock(tex, br0, 128, 2560, 1620, 128); //const28
        writeBlock(tex, br0, 128, 2432, 1620, 128); //const29
        writeBlock(tex, br0, 147456, 0, 1536, 1152); //const30
        writeBlock(tex, br0, 128, 2304, 1620, 128); //const31
        writeBlock(tex, br0, 128, 2560, 1625, 128); //const32
        writeBlock(tex, br0, 294912, 0, 1280, 1152); //const33
        writeBlock(tex, br0, 256, 2560, 1613, 256); //const34
        writeBlock(tex, br0, 256, 2304, 1614, 256); //const35
        writeBlock(tex, br0, 589824, 1152, 0, 576); //const36
        writeBlock(tex, br0, 256, 2304, 1615, 256); //const37
        writeBlock(tex, br0, 256, 2560, 1615, 256); //const38
        writeBlock(tex, br0, 589824, 576, 0, 576); //const39
        writeBlock(tex, br0, 256, 2560, 1616, 256); //const40
        writeBlock(tex, br0, 256, 2304, 1617, 256); //const41
        writeBlock(tex, br0, 589824, 0, 0, 576); //const42
        writeBlock(tex, br0, 256, 2304, 1618, 256); //const43
        writeBlock(tex, br0, 256, 2560, 1618, 256); //const44
        writeBlock(tex, br0, 589824, 2304, 0, 576); //const45
        writeBlock(tex, br0, 256, 2560, 1612, 256); //const46
        writeBlock(tex, br0, 256, 2304, 1612, 256); //const47
        writeBlock(tex, br0, 589824, 1728, 0, 576); //const48
        writeBlock(tex, br0, 256, 2560, 1610, 256); //const49
        writeBlock(tex, br0, 256, 2304, 1609, 256); //const50
        writeBlock(tex, br0, 8192, 2304, 1536, 128); //const51
        writeBlock(tex, br0, 128, 2432, 1621, 128); //const52
        writeBlock(tex, br0, 128, 2560, 1621, 128); //const53
        writeBlock(tex, br0, 65536, 2304, 1152, 512); //const54
        writeBlock(tex, br0, 128, 2304, 1622, 128); //const55
        writeBlock(tex, br0, 128, 2432, 1622, 128); //const56
        writeBlock(tex, br0, 524288, 0, 1024, 2048); //const57
        writeBlock(tex, br0, 128, 2688, 1622, 128); //const58
        writeBlock(tex, br0, 128, 2304, 1623, 128); //const59
        writeBlock(tex, br0, 6912, 2441, 1578, 384); //const60
        writeBlock(tex, br0, 18, 2858, 1628, 18); //const61
        writeBlock(tex, br0, 16128, 2441, 1536, 384); //const62
        writeBlock(tex, br0, 42, 2816, 1628, 42); //const63
        writeBlock(tex, br0, 4608, 2441, 1596, 384); //const64
        writeBlock(tex, br0, 12, 2304, 1629, 12); //const65

        writeBlock(tex, br1, 64, 2816, 1616, 64); //rm0
        writeBlock(tex, br1, 64, 2816, 1615, 64); //rv0
        writeBlock(tex, br1, 64, 2816, 1614, 64); //rm1
        writeBlock(tex, br1, 64, 2816, 1613, 64); //rv1
        writeBlock(tex, br1, 64, 2816, 1612, 64); //rm2
        writeBlock(tex, br1, 64, 2816, 1611, 64); //rv2
        writeBlock(tex, br1, 64, 2816, 1610, 64); //rm3
        writeBlock(tex, br1, 64, 2816, 1609, 64); //rv3
        writeBlock(tex, br1, 64, 2816, 1608, 64); //rm4
        writeBlock(tex, br1, 64, 2816, 1619, 64); //rv4
        writeBlock(tex, br1, 128, 2432, 1627, 128); //rm5
        writeBlock(tex, br1, 128, 2560, 1627, 128); //rv5
        writeBlock(tex, br1, 128, 2688, 1627, 128); //rm6
        writeBlock(tex, br1, 128, 2304, 1628, 128); //rv6
        writeBlock(tex, br1, 128, 2432, 1628, 128); //rm7
        writeBlock(tex, br1, 128, 2560, 1628, 128); //rv7
        writeBlock(tex, br1, 128, 2304, 1627, 128); //rm8
        writeBlock(tex, br1, 128, 2688, 1626, 128); //rv8
        writeBlock(tex, br1, 128, 2560, 1626, 128); //rm9
        writeBlock(tex, br1, 128, 2432, 1626, 128); //rv9
        writeBlock(tex, br1, 128, 2304, 1626, 128); //rm10
        writeBlock(tex, br1, 128, 2688, 1625, 128); //rv10
        writeBlock(tex, br1, 256, 2560, 1619, 256); //rm11
        writeBlock(tex, br1, 256, 2560, 1617, 256); //rv11
        writeBlock(tex, br1, 256, 2304, 1616, 256); //rm12
        writeBlock(tex, br1, 256, 2304, 1613, 256); //rv12
        writeBlock(tex, br1, 256, 2560, 1611, 256); //rm13
        writeBlock(tex, br1, 256, 2560, 1608, 256); //rv13
        writeBlock(tex, br1, 256, 2560, 1614, 256); //rm14
        writeBlock(tex, br1, 256, 2304, 1619, 256); //rv14
        writeBlock(tex, br1, 256, 2304, 1611, 256); //rm15
        writeBlock(tex, br1, 256, 2304, 1610, 256); //rv15
        writeBlock(tex, br1, 256, 2560, 1609, 256); //rm16
        writeBlock(tex, br1, 256, 2304, 1608, 256); //rv16
        writeBlock(tex, br1, 128, 2432, 1624, 128); //rm17
        writeBlock(tex, br1, 128, 2560, 1624, 128); //rv17
        writeBlock(tex, br1, 128, 2688, 1624, 128); //rm18
        writeBlock(tex, br1, 128, 2304, 1625, 128); //rv18
        writeBlock(tex, br1, 128, 2432, 1625, 128); //rm19
        writeBlock(tex, br1, 128, 2688, 1628, 128); //rv19
    }
}

#endif