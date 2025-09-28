package main

import "core:math/linalg/glsl"

Camera :: struct {
	matrices: CameraMatrix,
}

CameraMatrix :: struct {
	perspective: glsl.mat4,
	view:        glsl.mat4,
}

Camera_initilize :: proc() -> Camera {
	self: Camera
	return self

}
