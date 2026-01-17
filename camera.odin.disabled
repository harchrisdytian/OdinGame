package main


import fmt "core:fmt"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"


SENS : f32: 0.3
SPEED : f32:2.5

Camera :: struct {
    position : glm.vec3,
    front :glm.vec3,
    up : glm.vec3,
    worldUp:glm.vec3,
    right:glm.vec3,
    target: glm.vec3,
    roll:f32,
    pitch:f32,
    yaw:f32    
}
Direction :: enum{
    UP,
    LEFT,
    RIGHT,
    SPACE,
    DOWN
}
processCameraMouseMovements::proc "contextless"(camera : ^Camera,xoffset:f32,yoffset:f32){
    
    
    camera.yaw +=  xoffset *SENS
    camera.pitch +=  yoffset * SENS

    CameraRecalculateVectors(camera)
}

CameraViewMatrix ::proc(camera :Camera) -> glm.mat4{

    return glm.mat4LookAt(camera.position, camera.position + camera.front, camera.up)
}

CameraRecalculateVectors :: proc "contextless" (camera : ^Camera) {
    front :glm.vec3 =0
    front.x = math.cos(math.to_radians(camera.yaw))*math.cos(math.to_radians(camera.pitch))
    front.y = math.sin(math.to_radians(camera.pitch))
    front.z=  math.sin(math.to_radians(camera.yaw)) *math.cos( math.to_radians(camera.pitch))
    camera.front = glm.normalize_vec3(front)
    camera.right = glm.normalize(glm.cross(camera.front,camera.worldUp))
    camera.up = glm.normalize(glm.cross(camera.right,camera.front))
    
}

CameraProcessMovement :: proc "contextless" (camera:^Camera,MovementDir:Direction,speed :f32=0.5){

    switch MovementDir{
        case .DOWN:
            camera.position -= camera.front * speed
        case .UP:
            camera.position += camera.front * speed
        case .LEFT:
            camera.position -=camera.right *speed
        case.RIGHT:
            camera.position += camera.right *speed
        case .SPACE:
            camera.position += camera.up * speed;
    }
    //fmt.println(camera.position)
    CameraRecalculateVectors(camera)
}