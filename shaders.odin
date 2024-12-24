
package main

import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"
import "core:fmt"

UniformValue :: struct{
    location : i32,
    name : cstring,
    value :ShaderValue
}  
ShaderValue :: union{
    f32,
    [3]f32,
    i32,
    [3]i32,
    glm.mat4
}


Material :: struct {
    texture: u32
}
Light :: struct {
    direction:UniformValue,
    position:UniformValue,
    
    ambient:UniformValue,
    constant:UniformValue,
    linear:UniformValue,
    quadratic:UniformValue,

    diffuse:UniformValue,
    specular:UniformValue,

    cutOff:UniformValue
}
MaterialParam :: struct {
    shininess:UniformValue,
    diffuse:UniformValue,
    specular:UniformValue,
}
Shadder :: struct {
    model: UniformValue,
    projection: UniformValue,
    view: UniformValue,
    viewPos:UniformValue,
    
    mProgram: u32,
    mMaterial: MaterialParam,
    mLight: Light
    
}

UniformValue_make :: proc (prog: u32,
    name: cstring,
    value : ShaderValue, 
    alloc := context.allocator ) -> UniformValue
{
   loc := gl.GetUniformLocation(prog,name)
   return UniformValue {location = loc,name = name,value = value};
} 

UniformValue_set:: proc (value:UniformValue)
{
    switch &v in value.value{
        case f32:
            gl.Uniform1fv(value.location,1,&v);
        case [3]f32:
            gl.Uniform3fv(value.location,1,&v[0])
        case i32:
            gl.Uniform1iv(value.location,1,&v);
        case [3]i32:
            gl.Uniform3iv(value.location,1,&v[0]);
        case glm.mat4:
            gl.UniformMatrix4fv(value.location,1,gl.FALSE,&v[0][0])
     
    }
}
