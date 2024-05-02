package main

import math "core:math/linalg"
import glm "core:math/linalg/glsl"

import  gl "vendor:OpenGL"
import cgltf "vendor:cgltf"
import stb "vendor:stb/image"
import "core:fmt"
import "core:slice"
import "core:bytes"


Vertex :: struct{
    position:glm.vec3,
    normal:glm.vec3,
    uv:glm.vec2,
}
Texture :: struct{
    type: u32
}
buffers ::struct{
    VBO:u32,
    VAO:u32,
    EBO:u32,
} 

Model:: struct{
    vertices :[dynamic]Vertex,
    indicies: [dynamic]u32,
    textures: u32,
    buffer:buffers
}


Image:: struct{
    data :[]byte
}

ModelCreatePath::proc(path:cstring, alloc := context.allocator ) -> Model{
    options :cgltf.options
    data : ^cgltf.data
    res: cgltf.result
    Value : Model
    albedo_data :[^]byte
    
    //loading the data
    data, res = cgltf.parse_file(options,path)
    defer cgltf.free(data)
    
        
        if(res != cgltf.result.success)
        {
            fmt.print("ERROR: did not parse the gltf file")
            return Value
        } 
        res = cgltf.load_buffers(options,data,path)   
        if(res != cgltf.result.success)
        {
            fmt.print("ERROR: did not load the gltf file")
            return Value
        }
        res = cgltf.validate(data);
        if(res != cgltf.result.success)
        {
            fmt.print("ERROR: did not validate the gltf file")
            return Value;
        }
    
    
    //fmt.print(data.nodes[0])0
    for node, index in data.nodes{
        //node : cgltf.node
       // fmt.print(node)
        mesh := node.mesh
        if mesh == nil
        {

            continue
        }
        //fmt.print(mesh.primitives[0])
        
        for primitive in node.mesh.primitives{
            //primitive : cgltf.primitive
            Value.vertices = make( [dynamic]Vertex,
                primitive.attributes[0].data.count ,
                primitive.attributes[0].data.count  )    
               // fmt.print("help")
            //fmt.print(primitive.attributes)
            for i in 0..< primitive.indices.count{
                append(&Value.indicies,u32(cgltf.accessor_read_index(primitive.indices,i)))
            }
            
            if(primitive.material != nil && primitive.material.has_pbr_metallic_roughness)
            {
                prim_texture :^cgltf.texture
                if(primitive.material.pbr_metallic_roughness.base_color_texture.texture !=nil){

                    prim_texture = primitive.material.pbr_metallic_roughness.base_color_texture.texture
                    fmt.println("texture data")
                }

                buffer_view := prim_texture.image_.buffer_view
                
                color_data := buffer_view.buffer.data
                //color_offset := buffer_view.offset
                color_data_size := buffer_view.size
                fmt.println(prim_texture.image_.mime_type)

                if(color_data != nil){
                
                    albedo_data :[^]byte= (cast([^]byte)(uintptr(color_data)))
                    //fmt.printf("somebit %d \n",&albedo_data[1])
                    width,height ,nrComponents:i32
                    
                    albedo_data = stb.load_from_memory(albedo_data,i32(buffer_view.buffer.size),&width,&height,&nrComponents,0)
                    fmt.printf("somebit2 %#04hhx  \n",albedo_data[7343])
                    fmt.print("width", width)
                   Value.textures = gltf_load_texture(albedo_data,width,height,nrComponents)
                    
                }
                
                //fmt.println("anything: " )
            }

            for attribute in primitive.attributes{
                //fmt.print("something ")

                //attribute : cgltf.attribute
                acessor : ^cgltf.accessor
                acessor = attribute.data
                float_data : [dynamic]f32
                //fmt.println(attribute.type)
                #partial switch  acessor.type{
                    case cgltf.type.vec2: 
                    {   
                        fmt.print("anything ")
                        float_data = GltfGetFloats(2,acessor)
                    }
                    case cgltf.type.vec3: 
                    {
                        fmt.print("anything ")

                        float_data = GltfGetFloats(3,acessor)
                    }
                    case cgltf.type.vec4: 
                    {
                        fmt.print("anything " )

                        float_data = GltfGetFloats(4,acessor)
                    }
                }         
                 
                if attribute.type == cgltf.attribute_type.position
                {
                   
                    
                    for i :=0; i < (len(float_data)) ;i+=3
                    {    
                        Value.vertices[i/3].position = {float_data[i],float_data[i+1],float_data[i+2] }
                        //fmt.println("pos: ",Value.vertices[i/3].position )
                        
                    }
                }
                if(attribute.type == cgltf.attribute_type.normal){
                   // fmt.print(" normal ")

                    for i :=0; i < (len(float_data));i+=3
                    {    
                        Value.vertices[i/3].normal = {float_data[i],float_data[i+1],float_data[i+2]}
                        if glm.length_vec3(Value.vertices[i/3].normal) > 0.0001
                        {
                            Value.vertices[i/3].normal = {0.0,1.0,0.0}
                        }
                    }
                }
                if attribute.type == cgltf.attribute_type.texcoord
                {
                    for i :=0; i< (len(float_data) ) - 1 ;i+=2
                    {    
                        Value.vertices[i/2 ].uv = {float_data[i],float_data[i+1]}
                    }
                }
            
            }
            
        }
    }  
    //fmt.print("something")
    
    return Value
}

GltfGetFloats :: proc(componentCount : uint, Acessor : ^cgltf.accessor, alloc := context.allocator) -> [dynamic]f32{
    floats : [dynamic]f32

    resize(&floats, int(componentCount * Acessor.count))
    res :b32
    //Acessor :cgltf.accessor
    
    for i:uint= 0; i <(Acessor.count) ; i+=1 {
       res = cgltf.accessor_read_float(Acessor,uint(i ),&floats[i * componentCount],componentCount)
    }
    
    if(res){
        return floats
    } 
    else {
        return floats
    }
}


ModelCreate::proc( vertices :[dynamic]Vertex,
    indicies: [dynamic]u32,
    textures: u32,
    alloc := context.allocator ) -> Model 
    {
    
    result := Model{vertices = vertices,indicies= indicies,textures= textures}

    setupMesh(&result)
    return result

}

setupMesh ::proc(_model : ^Model, alloc :=context.allocator)
    {
    gl.GenVertexArrays(1,&_model.buffer.VAO)
    gl.GenBuffers(1, &_model.buffer.VBO)
    gl.GenBuffers(1, &_model.buffer.EBO)

    gl.BindVertexArray(_model.buffer.VAO)
    
    gl.BindBuffer(gl.ARRAY_BUFFER, _model.buffer.VBO)

    fmt.println(len(_model.vertices))
    gl.BufferData(gl.ARRAY_BUFFER,len(_model.vertices) *size_of(_model.vertices[0]), &_model.vertices[0],gl.STATIC_DRAW)
    
    fmt.println(size_of(_model.indicies))
    
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER,_model.buffer.EBO)
    
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER,len(_model.indicies)*size_of(u32),&_model.indicies[0],gl.STATIC_DRAW)
    
    fmt.println(size_of(Vertex)," ",offset_of(Vertex,normal),offset_of(Vertex,uv))
    gl.EnableVertexAttribArray(0)
    gl.VertexAttribPointer(0,3,gl.FLOAT,gl.FALSE,size_of(Vertex),uintptr(0))
    
    gl.EnableVertexAttribArray(1)
    gl.VertexAttribPointer(1,3,gl.FLOAT,gl.FALSE,size_of(Vertex),uintptr(0)+offset_of(Vertex,normal))

    gl.EnableVertexAttribArray(2)
    gl.VertexAttribPointer(2,2,gl.FLOAT,gl.FALSE,size_of(Vertex),uintptr(0)+offset_of(Vertex,uv))
    
    gl.BindVertexArray(0)
}


gltf_load_texture ::proc(data: [^]byte, width :i32, height :i32, nrComponents:i32) ->   u32
{
    textureID :u32
    gl.GenTextures(1,&textureID)

    if (data != nil)
    {
		format : int
		if(nrComponents == 0)
		{
			format = gl.RED;
		}
		else if(nrComponents == 3){
			format = gl.RGB
		}
		else if(nrComponents == 4){
			format = gl.RGBA
		}
		gl.BindTexture(gl.TEXTURE_2D, textureID);
		gl.TexImage2D(gl.TEXTURE_2D, 0, i32(format), width, height, 0, u32(format), gl.UNSIGNED_BYTE, data);
		gl.GenerateMipmap(gl.TEXTURE_2D)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	}else{
		fmt.println("err: loaded image wrong")
		
	}

	return textureID		
    
}