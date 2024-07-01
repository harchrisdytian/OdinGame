package main

import glm "core:math/linalg/glsl"
import "core:fmt"
Level :: struct{
    Level : [dynamic]Scene
}

Player ::struct{
    gravity:f32,
    velocity:glm.vec3
}
mainPlayer:Player

spotA :glm.vec3
spotB :glm.vec3


CurrentLevel :Level;
MainLevel::proc(shader :^Shadder,lightDirection:glm.vec3,
    camera: Camera, view:glm.mat4, projection:glm.mat4)
{

    boxA :AxisAlignedBoundingBox
    boxA.center = spotA;
    boxA.size = {1,1,1}

    boxB :AxisAlignedBoundingBox
    
    boxB.center = spotB;
    boxB.size = {1,1,1}

    
    BaseCube.transform = 1
    BaseCube.transform *= glm.mat4Translate(boxA.center)
	draw_scene(BaseCube,shader,lightDirection,camera,view,projection)
    
    BaseCube.transform = 1
    BaseCube.transform *= glm.mat4Translate(boxB.center)
	draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

    if(AABB_AABB_Overlaps(boxA,boxB)){
        fmt.print("c")

    } else{
        fmt.print("n")
    }

    // BaseArch.transform = glm.mat4Translate({0,0.1,0})
    // BaseCube.transform = 1
	// draw_scene(BaseArch,shader,lightDirection,camera,view,projection)


    // BaseCube.transform = 1
    // //BaseCube.transform = glm.mat4Translate({0,0,0})
    // BaseCube.transform *= glm.mat4Scale({20,1,20})
    // draw_scene(BaseCube,shader,lightDirection,camera,view,projection)
    


    // BaseCube.transform = 1
    // BaseCube.transform *= glm.mat4Translate({-0.2,0.2,0.0})
    // BaseCube.transform *= glm.mat4Scale({1,20,20}) 
    // draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

    // BaseCube.transform = 1
    // BaseCube.transform *= glm.mat4Translate({0.2,0.2,0.0})
    // BaseCube.transform *= glm.mat4Scale({1,20,20}) 
    // draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

    // BaseCube.transform = 1
    // BaseCube.transform *= glm.mat4Translate({0,0.2,0.0})
    // BaseCube.transform *= glm.mat4Rotate({0,1,0},glm.PI/2)
    // BaseCube.transform *= glm.mat4Scale({1,20,20}) 
    // draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

}

