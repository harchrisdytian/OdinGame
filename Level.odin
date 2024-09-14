package main

import "core:fmt"
import math "core:math/linalg"
import glm "core:math/linalg/glsl"
Level :: struct {
	Level: [dynamic]Scene,
}

Player :: struct {
	gravity:  f32,
	velocity: glm.vec3,
}
mainPlayer: Player

spotA: glm.vec3
spotB: glm.vec3


CurrentLevel: Level
MainLevel :: proc(
	shader: ^Shadder,
	lightDirection: glm.vec3,
	camera: Camera,
	view: glm.mat4,
	projection: glm.mat4,
	ter:^terrain
) {

	tempModel: glm.mat4
	tempModel =1
	draw_terrain(tempModel,view,projection,ter)
	// boxA :OrientedBoundingBox
	// boxA.center = spotA;
	// boxA.size = {1,1,1}
	// boxA.orientation[0] = {1,0,0}
	// boxA.orientation[1] = {0,1,0}
	// boxA.orientation[2] = {0,0,1}

	// boxARotation := glm.mat4Rotate({0,1,0},glm.degrees_f32(45))
	// for &axis in boxA.orientation{
	//     newVal:glm.vec4
	//     newVal = glm.vec4({axis.x,axis.y,axis.z,0})
	//     axis = (newVal * boxARotation).xyz
	// }


	// boxB :OrientedBoundingBox

	// boxB.center = spotB;
	// boxB.size = {1,1,1}
	// boxB.orientation[0] = {1,0,0}
	// boxB.orientation[1] = {0,1,0}
	// boxB.orientation[2] = {0,0,1}


	// BaseCube.transform = 1
	// BaseCube.transform *= (  glm.mat4Translate(boxA.center) *  boxARotation  )

	// draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

	// BaseCube.transform = 1
	// BaseCube.transform *= glm.mat4Translate(boxB.center)
	// draw_scene(BaseCube,shader,lightDirection,camera,view,projection)

	// if(OBB_OBB_OverLaps(boxA,boxB)){
	//     fmt.print("c")

	// } else{
	//     fmt.print("n")
	// // }

	// BaseArch.transform = glm.mat4Scale({0.01,0.01,0.01})

	// // BaseCube.transform = 1
	// draw_scene(BaseArch, shader, lightDirection, camera, view, projection)


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
