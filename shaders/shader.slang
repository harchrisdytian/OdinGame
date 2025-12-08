
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

ConstantBuffer<uint> size;
Sampler2D Hightmap;
// struct TerrainInput
// {
//   uint pos
// }

[shader("vertex")]
VSOutput TerrainMain(uint input)
{
    VSOutput output;
    float x = (input % size);
    float y = (input / size);

    float2 uv = float2(x,y) / float(size - 1);

    float z = Hightmap.Sample(uv).r;   
    float4 pos = float4(x,y,z,0);
    output.pos = mul(ubo.proj,pos);
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
Sampler2D texture;

[shader("fragment")]
float4 fragMain(VSOutput vertIn) : SV_TARGET {
    return texture.Sample(vertIn.fragTexCoord);
}
