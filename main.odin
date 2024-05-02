package main

import "core:fmt"
import "core:c"
import "vendor:glfw"
import gl "vendor:OpenGL"


running : b32 =true

main :: proc(){

    
    init()

    for ( !glfw.WindowShouldClose(window) && running){
        glfw.PollEvents()

        update()
        draw()

        glfw.SwapBuffers(window)
    }
    end(window)
}
