package main

import "base:runtime"
import "core:fmt"
import glm "core:math/linalg/glsl"
import "vendor:glfw"
Input :: struct {
	input: glm.vec3,
}

HandleInput :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	using engine.player.input
	holding: f32 = 0.0
	context = runtime.default_context()
	if (action == glfw.PRESS) {
		holding = f32(1.0)
	} else if (action == glfw.RELEASE) {
		holding = f32(0.0)
	}
	if (key == glfw.KEY_W || key == glfw.KEY_UP) {
		input.y = holding
		fmt.printf("Holding w")
	}
	if (key == glfw.KEY_D || key == glfw.KEY_DOWN) {
		input.y = -holding
	}
	if (key == glfw.KEY_A || key == glfw.KEY_LEFT) {
		input.x = -holding
	}
	if (key == glfw.KEY_D || key == glfw.KEY_RIGHT) {
		input.x = holding
	}
	if (key == glfw.KEY_Q || key == glfw.KEY_LEFT_SHIFT || key == glfw.KEY_RIGHT_SHIFT) {
		input.z = -holding
	}
	if (key == glfw.KEY_E || key == glfw.KEY_LEFT_CONTROL || key == glfw.KEY_RIGHT_CONTROL) {
		input.z = holding
	}
}
