package main

import glm "core:math/linalg/glsl"

// taken from real-time collison by christipher ericson
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
    ra,rb:f32
    Rotation, absoluteRotation:glm.mat3

    // computr boxes rotation in terms of b

    for i in 0..=2{
        for j in 0..=2{
            Rotation[i][j] = glm.dot_vec3(BoxA.orientation[i],BoxB.orientation[j])
        }
    }

    RelativeSpace : glm.vec3

    RelativeSpace = BoxB.center - BoxA.center
    RelativeSpace = {glm.dot(RelativeSpace,BoxA.orientation[0]),glm.dot(RelativeSpace,BoxA.orientation[1]),glm.dot(RelativeSpace,BoxA.orientation[2])}

    // calcualte common subexpression
    for i in 0..=2{
        for j in 0..=2{
            absoluteRotation[i][j] = abs(Rotation[i][j]) + glm.F32_EPSILON
        }
    }

    //test axes = A0, A1, A2
    for i in 0..=2{
        ra = BoxA.size[i]
        rb = BoxB.size[0] * absoluteRotation[i][0] + BoxB.size[1] * absoluteRotation[i][1] + BoxB.size[2] * absoluteRotation[i][2]
        if( abs(RelativeSpace[i]) > ra + rb ){
            return false
        }
    }

    // Test axes L = B0, L = B1, L = B2
    for i in 0..=2{
        ra = BoxA.size[0] * absoluteRotation[0][i] + BoxA.size[1] * absoluteRotation[1][i] + BoxA.size[2] * absoluteRotation[2][i]
        rb = BoxB.size[i]
        if(abs(RelativeSpace[0] * Rotation[0][i] + RelativeSpace[1] * Rotation[1][i] + RelativeSpace[2] * Rotation[2][i]) > ra + rb){
            return false
        }
    }

    // a0 X B0
    ra = BoxA.size[1] * absoluteRotation[2][0] + BoxA.size[2] * absoluteRotation[1][0]
    rb = BoxB.size[1] * absoluteRotation[0][2] + BoxB.size[2] * absoluteRotation[0][1]
    if (abs(RelativeSpace[2] * Rotation[1][0] - RelativeSpace[1] * Rotation[2][0]) > ra + rb) 
    {
        return false
    }

    // Test axis L = A0 x B1
    ra = BoxA.size[1] * absoluteRotation[2][1] + BoxA.size[2] * absoluteRotation[1][1];
    rb = BoxB.size[0] * absoluteRotation[0][2] + BoxB.size[2] * absoluteRotation[0][0];
    if (abs(RelativeSpace[2] * Rotation[1][1] - RelativeSpace[1] * Rotation[2][1]) > ra + rb)
    {
        return false
    } 
    // Test axis L = A0 x B2
    ra = BoxA.size[1] * absoluteRotation[2][2] + BoxA.size[2] * absoluteRotation[1][2];
    rb = BoxB.size[0] * absoluteRotation[0][1] + BoxB.size[1] * absoluteRotation[0][0];
    if (abs(RelativeSpace[2] * Rotation[1][2] - RelativeSpace[1] * Rotation[2][2]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A1 x B0
    ra = BoxA.size[0] * absoluteRotation[2][0] + BoxA.size[2] * absoluteRotation[0][0];
    rb = BoxB.size[1] * absoluteRotation[1][2] + BoxB.size[2] * absoluteRotation[1][1];

    if (abs(RelativeSpace[0] * Rotation[2][0] - RelativeSpace[2] * Rotation[0][0]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A1 x B1
    ra = BoxA.size[0] * absoluteRotation[2][1] + BoxA.size[2] * absoluteRotation[0][1];
    rb = BoxB.size[0] * absoluteRotation[1][2] + BoxB.size[2] * absoluteRotation[1][0];
    if (abs(RelativeSpace[0] * Rotation[2][1] - RelativeSpace[2] * Rotation[0][1]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A1 x B2
    ra = BoxA.size[0] * absoluteRotation[2][2] + BoxA.size[2] * absoluteRotation[0][2];
    rb = BoxB.size[0] * absoluteRotation[1][1] + BoxB.size[1] * absoluteRotation[1][0];
    if (abs(RelativeSpace[0] * Rotation[2][2] - RelativeSpace[2] * Rotation[0][2]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A2 x B0
    ra = BoxA.size[0] * absoluteRotation[1][0] + BoxA.size[1] * absoluteRotation[0][0];
    rb = BoxB.size[1] * absoluteRotation[2][2] + BoxB.size[2] * absoluteRotation[2][1];
    if (abs(RelativeSpace[1] * Rotation[0][0] - RelativeSpace[0] * Rotation[1][0]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A2 x B1
    ra = BoxA.size[0] * absoluteRotation[1][1] + BoxA.size[1] * absoluteRotation[0][1];
    rb = BoxB.size[0] * absoluteRotation[2][2] + BoxB.size[2] * absoluteRotation[2][0];
    if (abs(RelativeSpace[1] * Rotation[0][1] - RelativeSpace[0] * Rotation[1][1]) > ra + rb) 
    {
        return false
    }
    // Test axis L = A2 x B2
    ra = BoxA.size[0] * absoluteRotation[1][2] + BoxA.size[1] * absoluteRotation[0][2];
    rb = BoxB.size[0] * absoluteRotation[2][1] + BoxB.size[1] * absoluteRotation[2][0];
    if (abs(RelativeSpace[1] * Rotation[0][2] - RelativeSpace[0] * Rotation[1][2]) > ra + rb) 
    {
        return false
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
