package main

import "core:fmt"
import "core:c"
import "core:mem"
import "core:log"
import "vendor:glfw"
import gl "vendor:OpenGL"


running : b32 =true

main :: proc(){
     when ODIN_DEBUG {
        context.logger = log.create_console_logger(opt = {.Level, .Terminal_Color})
        defer log.destroy_console_logger(context.logger)

        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                log.errorf("=== %v allocations not freed: ===", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    log.debugf("%v bytes @ %v", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                log.errorf("=== %v incorrect frees: ===", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    log.debugf("%p @ %v", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    
    init()

    for ( !glfw.WindowShouldClose(window) && running){
        glfw.PollEvents()

        update()
        draw()

        glfw.SwapBuffers(window)
    }
    end(window)
}
