using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;

public class MassMeshes : MonoBehaviour
{
    public Mesh origin;
    public int numMeshes;
    public Material drawMat;
	public bool castShadow = true;
	public bool reserveShadow = true;

    Mesh mesh;
    int numInSingleMesh;//１つのmeshに、いくつ、originのメッシュが入っているか。
    int numDraw;//Graphics.DrawMesh()を呼ぶ回数
    MaterialPropertyBlock mPropBlock;
    // Use this for initialization
    void Start()
    {
        //ひとつのMeshObjectには、65000頂点まで入る。ので、限界まで、元になるメッシュ(origin)のデータを詰め込んだメッシュ(mesh)を作る。
        //mesh.uv2.xの値をそれぞれ、指定しておくことで、shader内で個別に処理できるようにしている。
        CreateMesh();
		
        numDraw = numMeshes / numInSingleMesh;
        if (numDraw * numInSingleMesh < numMeshes)
            numDraw++;
        mPropBlock = new MaterialPropertyBlock();
    }

    void CreateMesh()
    {
        var totalVerts = origin.vertexCount * numMeshes;
        numInSingleMesh = totalVerts <= 65000 ? numMeshes : 65000 / origin.vertexCount;

        mesh = new Mesh();
        var vCount = numInSingleMesh * origin.vertexCount;
        var vertices = new Vector3[vCount];
        var normals = new Vector3[vCount];
        var uv = new Vector2[vCount];
        var uv2 = new Vector2[vCount];
        var oIndices = origin.GetIndices(0);
        var indices = new int[oIndices.Length * numInSingleMesh];

        for (var i = 0; i < numInSingleMesh; i++)
        {
			for (var j = 0; j < origin.vertexCount; j++)
            {
                var index = j + i * origin.vertexCount;
                vertices[index] = origin.vertices[j];
                normals[index] = origin.normals[j];
                uv[index] = origin.uv[j];
                uv2[index] = new Vector2((float)i + 0.5f, 0.5f);
            }
            for (var j = 0; j < oIndices.Length; j++)
            {
                var index = j + i * oIndices.Length;
                indices[index] = oIndices[j] + i * origin.vertexCount;
            }
        }
        mesh.vertices = vertices;
        mesh.normals = normals;
        mesh.uv = uv;
        mesh.uv2 = uv2;
        mesh.SetIndices(indices, origin.GetTopology(0), 0);

        mesh.hideFlags = HideFlags.HideAndDontSave;
    }

    // Update is called once per frame
    void Update()
    {
        for (var i = 0; i < numDraw; i++)
        {
            //MaterialPropertyBlockを使うと、Materialを新たに作らずに、独自の値をMaterialに渡した状態でDrawMeshできる。
            //もとのメッシュ１つ１つを判断するため、_Offsetの値を指定。
            mPropBlock.Clear();
            mPropBlock.AddFloat("_Offset", i * numInSingleMesh);
            Graphics.DrawMesh(mesh, transform.position, transform.rotation, drawMat, 0, null, 0, mPropBlock, reserveShadow, castShadow);
        }
    }
}
