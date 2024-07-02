package main

import glm "core:math/linalg/glsl"

// taken from real-time collison
// center represented by a point and
// size reprisented by half width extents
AxisAlignedBoundingBox :: struct{
    
    center : glm.vec3,
    size: glm.vec3
}

OrientedBoundingBox::struct{
    center : glm.vec3,
    orientation : [3]glm.vec3,
    size: glm.vec3
}

CollisionShape :: union{
    AxisAlignedBoundingBox,
    OrientedBoundingBox
}

OBB_OBB_OverLaps::proc( BoxA:OrientedBoundingBox,
                        BoxB :OrientedBoundingBox) -> bool
{
    rBoxA,rBoxB:f32
    Rotation, AbsoluteRotation:glm.mat3

    // computr boxes rotation in terms of b

    for i in 0..=2{
        for j in 0..=2{
            Rotation[i][j] = glm.dot_vec3(BoxA.orientation[i],BoxB.orientation[j])
        }
    }

    TransFrame : glm.vec3

    TransFrame = BoxB.center - BoxA.center
    TransFrame = {glm.dot(TransFrame,BoxA.orientation[0]),glm.dot(TransFrame,BoxA.orientation[2]),glm.dot(TransFrame,BoxA.orientation[2])}

    // calcualte common subexpression
    for i in 0..=2{
        for j in 0..=2{
            AbsoluteRotation[i][j] = abs(Rotation[i][j]) + glm.F32_EPSILON
        }
    }


    for i in 0..=2{
        rBoxA = BoxA.size[i]
        rBoxB = BoxB.size[0] * AbsoluteRotation[i][0] + BoxB.size[1] * AbsoluteRotation[i][1] + BoxB.size[2] * AbsoluteRotation[i][1]
        if( abs(TransFrame[i]) > rBoxA + rBoxB ){
            return false
        }
    }
    
    for i in 0..=2{
        rBoxA = BoxA.size[0] * AbsoluteRotation[0][i] + BoxA.size[1] * AbsoluteRotation[1][i] + BoxA.size[2] * AbsoluteRotation[2][i]
        rBoxB = BoxB.size[i]
        if(abs(TransFrame[0] * Rotation[0][i] - TransFrame[1] * Rotation[1][i] + TransFrame[2] * Rotation[2][i]) > rBoxA +rBoxB){
            return false
        }
    }

    return true
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
