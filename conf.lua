function love.conf(t)
    t.identity = "lastcircle"
    t.version = "11.5"
    t.console = false
    t.window.title = "LastCircle - Cliente Lua (offline v0.1)"
    t.window.width = 1280
    t.window.height = 720
    t.window.minwidth = 900
    t.window.minheight = 540
    t.window.resizable = true
    t.window.vsync = 1
    t.modules.physics = false
end
