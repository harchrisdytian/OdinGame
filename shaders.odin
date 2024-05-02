
package main

import gl "vendor:OpenGL"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"


UniformValue :: struct{
    location : i32,
    name : cstring,
    value :ShaderValue
}  
ShaderValue ::union{
    f32,
    [3]f32,
    i32,
    [3]i32,
    glm.vec3
}


Material :: struct{
    texture: u32
}
 
UniformValue_make :: proc (prog: u32,
    name: cstring,
    value : ShaderValue, 
    alloc := context.allocator ) -> UniformValue
    {
   loc := gl.GetUniformLocation(prog,name)
   
   return UniformValue {location = loc,name = name,value = value};
} 

UniformValue_set:: proc (prog:u32,value:UniformValue)
{
    switch &v in value.value{
        case f32:
            gl.Uniform1fv(value.location,1,&v);
        case [3]f32:
            gl.Uniform3fv(value.location,1,&v[0])
        case glm.vec3:
            gl.Uniform3fv(value.location,1,&v[0])
        case i32:
            gl.Uniform1iv(value.location,1,&v);
        case [3]i32:
            gl.Uniform3iv(value.location,1,&v[0]);
     
    }
}