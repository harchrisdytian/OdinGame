
struct VSInput {
    float3 inPosition;
    float3 inColor;
    float2 inTexCoord;
};

struct UniformBuffer {
    float4x4 model;
    float4x4 view;
    float4x4 proj;
};
ConstantBuffer<UniformBuffer> ubo;

struct VSOutput
{
    float4 pos : SV_Position;
    float3 color;
    float2 fragTexCoord;
};

// struct Terrain
// {
//     uint size;
// }

struct terrain
{
    uint32_t size;
}
ConstantBuffer<terrain> size;

Sampler2D texture;

Sampler2D Hightmap;
// struct TerrainInput
// {
//   uint pos
// }

[shader("vertex")]
VSOutput TerrainMain(uint input: SV_VertexID)
{
    VSOutput output;
    uint width, height;
    Hightmap.GetDimensions(width,height);
    uint gridSize = width -1;

    float x = (input % gridSize);
    float y = (input / gridSize);

    float2 uv = float2(x,y) / gridSize -1
    ;

    // float scale = 0.1 / float(size);
    // float offsetX = (x- float(size) * 0.5)* scale;
    // float offsetY = (y- float(size) * 0.5)* scale;

    float z = Hightmap.SampleLevel(uv,1).r;   
    float4 pos = float4(x,y,z *1000,1);
    float4 viewPos = mul(ubo.view, pos);
    // output.pos = mul(ubo.proj, viewPos);

    output.pos = mul(ubo.proj, mul(ubo.view, mul(ubo.model, pos)));
    output.color = (1,1,1);
    output.fragTexCoord = uv;

    return output;
}


[shader("vertex")]
VSOutput vertMain(VSInput input) {
    VSOutput output;
    // output.pos = float4(input.inPosition, 0.0, 1.0);
    output.pos = mul(ubo.proj, mul(ubo.view, mul(ubo.model, float4(input.inPosition, 1.0))));
    output.fragTexCoord = input.inTexCoord;
    output.color = input.inColor;
    return output;
}

[shader("fragment")]
float4 fragMain(VSOutput vertIn) : SV_TARGET {
    // return texture.Sample(vertIn.fragTexCoord);
    return float4(1,1,1,1);
}
