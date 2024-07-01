package main

import glm "core:math/linalg/glsl"

// taken from real-time collison
// center represented by a point and
// size reprisented by half width extents
AxisAlignedBoundingBox :: struct{
    
    center : glm.vec3,
    size: glm.vec3
}
Sphere:: struct{

}
CollisionShape :: union{
    AxisAlignedBoundingBox,
}

AABB_AABB_Overlaps::proc (BoxA:AxisAlignedBoundingBox,
                         BoxB :AxisAlignedBoundingBox)-> bool
{
    for i in 0..=2{
        if abs(BoxA.center[i] - BoxB.center[i]) > BoxA.size[i] + BoxB.size[i]{
            return false
        }
    }
    return true

}

simulated_nums::proc(camera :^Camera){
   camera.position.x -= 0.1
}
