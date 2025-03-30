local GRID_SIZE = 9
local CELL_SIZE = 25
local MINE_COUNT = 10
local HEADER_HEIGHT = 40
local BORDER_SIZE = 15

local COLOR_BG = {192, 192, 192, 255}
local COLOR_LIGHT_3D = {255, 255, 255, 255}
local COLOR_DARK_3D = {128, 128, 128, 255}
local COLOR_VERY_DARK_3D = {64, 64, 64, 255}
local COLOR_TEXT = {0, 0, 0, 255}

local NUMBER_COLORS = {
    {0, 0, 255, 255},
    {0, 128, 0, 255},
    {255, 0, 0, 255},
    {0, 0, 128, 255},
    {128, 0, 0, 255},
    {0, 128, 128, 255},
    {0, 0, 0, 255},
    {128, 128, 128, 255}
}

local visible = true
local pos_x = 100
local pos_y = 100
local drag_offset_x = 0
local drag_offset_y = 0
local dragging = false
local game_over = false
local win = false
local reset_timer = 0
local cooldown = false

local grid = {}
local revealed = {}
local flagged = {}

local font_small = nil
local font_large = nil

local function init()
    grid = {}
    revealed = {}
    flagged = {}
    game_over = false
    win = false
    
    local viewport_w, viewport_h = render.get_viewport_size()
    local width = GRID_SIZE * CELL_SIZE + (BORDER_SIZE * 2)
    local height = HEADER_HEIGHT + GRID_SIZE * CELL_SIZE + BORDER_SIZE
    
    pos_x = math.floor((viewport_w - width) / 2)
    pos_y = math.floor((viewport_h - height) / 2)
    
    if font_small == nil then
        font_small = render.create_font("Arial", 12, 700)
    end
    
    if font_large == nil then
        font_large = render.create_font("Arial", 14, 700)
    end
    
    for y = 1, GRID_SIZE do
        grid[y] = {}
        revealed[y] = {}
        flagged[y] = {}
        for x = 1, GRID_SIZE do
            grid[y][x] = 0
            revealed[y][x] = false
            flagged[y][x] = false
        end
    end
    
    local mines = 0
    while mines < MINE_COUNT do
        local tick = winapi.get_tickcount64() + mines * 37
        math.randomseed(tick % 10000)
        
        local x = math.random(1, GRID_SIZE)
        local y = math.random(1, GRID_SIZE)
        
        if grid[y][x] ~= -1 then
            grid[y][x] = -1
            mines = mines + 1
        end
    end
    
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            if grid[y][x] ~= -1 then
                local count = 0
                
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and nx <= GRID_SIZE and ny >= 1 and ny <= GRID_SIZE then
                            if grid[ny][nx] == -1 then
                                count = count + 1
                            end
                        end
                    end
                end
                
                grid[y][x] = count
            end
        end
    end
end

local function draw_3d_border(x, y, width, height, raised)
    render.draw_line(x, y, x + width, y, COLOR_DARK_3D[1], COLOR_DARK_3D[2], COLOR_DARK_3D[3], COLOR_DARK_3D[4], 1)
    render.draw_line(x, y, x, y + height, COLOR_DARK_3D[1], COLOR_DARK_3D[2], COLOR_DARK_3D[3], COLOR_DARK_3D[4], 1)
    render.draw_line(x + width, y, x + width, y + height, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
    render.draw_line(x, y + height, x + width, y + height, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
    
    if raised then
        render.draw_line(x + 1, y + 1, x + width - 1, y + 1, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
        render.draw_line(x + 1, y + 1, x + 1, y + height - 1, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
        render.draw_line(x + width - 1, y + 1, x + width - 1, y + height - 1, COLOR_DARK_3D[1], COLOR_DARK_3D[2], COLOR_DARK_3D[3], COLOR_DARK_3D[4], 1)
        render.draw_line(x + 1, y + height - 1, x + width - 1, y + height - 1, COLOR_DARK_3D[1], COLOR_DARK_3D[2], COLOR_DARK_3D[3], COLOR_DARK_3D[4], 1)
    else
        render.draw_line(x + 1, y + 1, x + width - 1, y + 1, COLOR_VERY_DARK_3D[1], COLOR_VERY_DARK_3D[2], COLOR_VERY_DARK_3D[3], COLOR_VERY_DARK_3D[4], 1)
        render.draw_line(x + 1, y + 1, x + 1, y + height - 1, COLOR_VERY_DARK_3D[1], COLOR_VERY_DARK_3D[2], COLOR_VERY_DARK_3D[3], COLOR_VERY_DARK_3D[4], 1)
        render.draw_line(x + width - 1, y + 1, x + width - 1, y + height - 1, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
        render.draw_line(x + 1, y + height - 1, x + width - 1, y + height - 1, COLOR_LIGHT_3D[1], COLOR_LIGHT_3D[2], COLOR_LIGHT_3D[3], COLOR_LIGHT_3D[4], 1)
    end
end

local function draw_face_button(x, y, size)
    render.draw_rectangle(x, y, size, size, COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4], 1, true)
    
    if game_over then
        if win then
            draw_3d_border(x, y, size, size, false)
            
            render.draw_circle(x + size/2, y + size/2, size/3, 255, 255, 0, 255, 1, true)
            
            render.draw_rectangle(x + size/3 - 2, y + size/2 - 3, size/6, size/8, 0, 0, 0, 255, 1, true)
            render.draw_rectangle(x + size/2 + 2, y + size/2 - 3, size/6, size/8, 0, 0, 0, 255, 1, true)
            
            render.draw_line(x + size/3, y + size/2 + 5, x + size*2/3, y + size/2 + 5, 0, 0, 0, 255, 2)
        else
            draw_3d_border(x, y, size, size, false)
            
            render.draw_circle(x + size/2, y + size/2, size/3, 255, 255, 0, 255, 1, true)
            
            render.draw_line(x + size/3 - 2, y + size/2 - 3, x + size/3 + 2, y + size/2 + 1, 0, 0, 0, 255, 1)
            render.draw_line(x + size/3 - 2, y + size/2 + 1, x + size/3 + 2, y + size/2 - 3, 0, 0, 0, 255, 1)
            
            render.draw_line(x + size*2/3 - 2, y + size/2 - 3, x + size*2/3 + 2, y + size/2 + 1, 0, 0, 0, 255, 1)
            render.draw_line(x + size*2/3 - 2, y + size/2 + 1, x + size*2/3 + 2, y + size/2 - 3, 0, 0, 0, 255, 1)
            
            render.draw_line(x + size/3, y + size/2 + 7, x + size*2/3, y + size/2 + 7, 0, 0, 0, 255, 1)
            render.draw_line(x + size/3, y + size/2 + 8, x + size*2/3, y + size/2 + 6, 0, 0, 0, 255, 1)
        end
    else
        draw_3d_border(x, y, size, size, true)
        
        render.draw_circle(x + size/2, y + size/2, size/3, 255, 255, 0, 255, 1, true)
        
        render.draw_circle(x + size/3, y + size/2 - 2, 2, 0, 0, 0, 255, 1, true)
        render.draw_circle(x + size*2/3, y + size/2 - 2, 2, 0, 0, 0, 255, 1, true)
        
        render.draw_line(x + size/3, y + size/2 + 5, x + size*2/3, y + size/2 + 5, 0, 0, 0, 255, 1)
    end
end

local function draw_digit_display(x, y, width, height, value)
    render.draw_rectangle(x, y, width, height, 0, 0, 0, 255, 1, true)
    
    draw_3d_border(x, y, width, height, false)
    
    value = math.max(0, math.min(999, value))
    
    local str_value = string.format("%03d", value)
    
    for i = 1, 3 do
        render.draw_text(
            font_large, 
            string.sub(str_value, i, i), 
            x + 5 + (i-1)*(width/3 - 5), 
            y + height/2 - 7, 
            255, 0, 0, 255, 
            0, 0, 0, 0, 0
        )
    end
end

local function count_mines_remaining()
    local count = MINE_COUNT
    
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            if flagged[y][x] then
                count = count - 1
            end
        end
    end
    
    if count < 0 then
        count = 0
    end
    
    return count
end

local function draw()
    if not visible then
        return
    end
    
    local width = GRID_SIZE * CELL_SIZE + (BORDER_SIZE * 2)
    local height = HEADER_HEIGHT + GRID_SIZE * CELL_SIZE + BORDER_SIZE
    
    render.draw_rectangle(pos_x, pos_y, width, height, COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4], 1, true)
    draw_3d_border(pos_x, pos_y, width, height, true)
    
    render.draw_rectangle(pos_x + 10, pos_y + 10, width - 20, height - 20, COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4], 1, true)
    draw_3d_border(pos_x + 10, pos_y + 10, width - 20, height - 20, false)
    
    draw_digit_display(pos_x + 16, pos_y + 16, 60, 28, count_mines_remaining())
    
    draw_face_button(pos_x + width/2 - 15, pos_y + 15, 30)
    
    render.draw_text(
        font_small,
        "[INSERT]",
        pos_x + width - 70,
        pos_y + 20,
        COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], COLOR_TEXT[4],
        0, 0, 0, 0, 0
    )
    
    local grid_start_x = pos_x + BORDER_SIZE
    local grid_start_y = pos_y + HEADER_HEIGHT + 5
    
    local grid_width = GRID_SIZE * CELL_SIZE + 2
    local grid_height = GRID_SIZE * CELL_SIZE + 2
    draw_3d_border(grid_start_x - 1, grid_start_y - 1, grid_width, grid_height, false)
    
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            local cell_x = grid_start_x + (x - 1) * CELL_SIZE
            local cell_y = grid_start_y + (y - 1) * CELL_SIZE
            
            if revealed[y][x] then
                render.draw_rectangle(
                    cell_x, 
                    cell_y, 
                    CELL_SIZE, 
                    CELL_SIZE, 
                    COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4], 
                    1, 
                    true
                )
                
                render.draw_rectangle(
                    cell_x, 
                    cell_y, 
                    CELL_SIZE, 
                    CELL_SIZE, 
                    COLOR_DARK_3D[1], COLOR_DARK_3D[2], COLOR_DARK_3D[3], COLOR_DARK_3D[4], 
                    1, 
                    false
                )
                
                if grid[y][x] == -1 then
                    render.draw_circle(
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE/2, 
                        CELL_SIZE/3 - 2, 
                        0, 0, 0, 255, 
                        1, 
                        true
                    )
                    
                    render.draw_line(
                        cell_x + CELL_SIZE/4, 
                        cell_y + CELL_SIZE/2, 
                        cell_x + CELL_SIZE*3/4, 
                        cell_y + CELL_SIZE/2, 
                        0, 0, 0, 255, 
                        1
                    )
                    render.draw_line(
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE/4, 
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE*3/4, 
                        0, 0, 0, 255, 
                        1
                    )
                    
                    render.draw_circle(
                        cell_x + CELL_SIZE/2 - 2, 
                        cell_y + CELL_SIZE/2 - 2, 
                        2, 
                        255, 255, 255, 255, 
                        1, 
                        true
                    )
                    
                    if game_over and not win and grid[y][x] == -1 and revealed[y][x] then
                        render.draw_rectangle(
                            cell_x + 1, 
                            cell_y + 1, 
                            CELL_SIZE - 2, 
                            CELL_SIZE - 2, 
                            255, 0, 0, 180, 
                            1, 
                            true
                        )
                    end
                elseif grid[y][x] > 0 then
                    local num = grid[y][x]
                    local color = NUMBER_COLORS[num]
                    
                    render.draw_text(
                        font_large, 
                        tostring(num), 
                        cell_x + CELL_SIZE/2 - 4, 
                        cell_y + CELL_SIZE/2 - 8, 
                        color[1], color[2], color[3], color[4], 
                        0, 0, 0, 0, 0
                    )
                end
            else
                render.draw_rectangle(
                    cell_x, 
                    cell_y, 
                    CELL_SIZE, 
                    CELL_SIZE, 
                    COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], COLOR_BG[4], 
                    1, 
                    true
                )
                
                draw_3d_border(cell_x, cell_y, CELL_SIZE, CELL_SIZE, true)
                
                if flagged[y][x] then
                    render.draw_rectangle(
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE/5, 
                        1, 
                        CELL_SIZE*3/5, 
                        0, 0, 0, 255, 
                        1, 
                        true
                    )
                    
                    render.draw_triangle(
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE/5, 
                        cell_x + CELL_SIZE*3/4, 
                        cell_y + CELL_SIZE/3, 
                        cell_x + CELL_SIZE/2, 
                        cell_y + CELL_SIZE/2, 
                        255, 0, 0, 255, 
                        1, 
                        true
                    )
                    
                    render.draw_rectangle(
                        cell_x + CELL_SIZE/3, 
                        cell_y + CELL_SIZE*4/5, 
                        CELL_SIZE/3, 
                        CELL_SIZE/10, 
                        0, 0, 0, 255, 
                        1, 
                        true
                    )
                end
            end
        end
    end
end

local function check_win()
    for y = 1, GRID_SIZE do
        for x = 1, GRID_SIZE do
            if grid[y][x] ~= -1 and not revealed[y][x] then
                return false
            end
        end
    end
    
    return true
end

local function reveal(x, y)
    if x < 1 or x > GRID_SIZE or y < 1 or y > GRID_SIZE then
        return
    end
    
    if revealed[y][x] or flagged[y][x] or game_over then
        return
    end
    
    revealed[y][x] = true
    
    if grid[y][x] == -1 then
        game_over = true
        
        for my = 1, GRID_SIZE do
            for mx = 1, GRID_SIZE do
                if grid[my][mx] == -1 then
                    revealed[my][mx] = true
                end
            end
        end
        
        reset_timer = winapi.get_tickcount64() + 2000
        return
    end
    
    if grid[y][x] == 0 then
        for dy = -1, 1 do
            for dx = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    reveal(x + dx, y + dy)
                end
            end
        end
    end
    
    if check_win() then
        game_over = true
        win = true
        for ny = 1, GRID_SIZE do
            for nx = 1, GRID_SIZE do
                if grid[ny][nx] == -1 and not flagged[ny][nx] then
                    flagged[ny][nx] = true
                end
            end
        end
    end
end

local function toggle_flag(x, y)
    if x < 1 or x > GRID_SIZE or y < 1 or y > GRID_SIZE then
        return
    end
    
    if revealed[y][x] or game_over then
        return
    end
    
    flagged[y][x] = not flagged[y][x]
end

local function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

local function tick()
    if input.is_key_pressed(0x2D) then
        visible = not visible
    end
    
    if input.is_key_pressed(0x52) then
        init()
    end
    
    if game_over and reset_timer > 0 and winapi.get_tickcount64() >= reset_timer then
        init()
        reset_timer = 0
    end
    
    if visible then
        local mx, my = input.get_mouse_position()
        
        if dragging then
            if input.is_key_down(0x01) then
                pos_x = mx - drag_offset_x
                pos_y = my - drag_offset_y
            else
                dragging = false
            end
        else
            local width = GRID_SIZE * CELL_SIZE + (BORDER_SIZE * 2)
            local height = HEADER_HEIGHT + GRID_SIZE * CELL_SIZE + BORDER_SIZE
            local grid_start_x = pos_x + BORDER_SIZE
            local grid_start_y = pos_y + HEADER_HEIGHT + 5
            
            local reset_x = pos_x + width/2 - 15
            local reset_y = pos_y + 15
            local reset_size = 30
            
            if input.is_key_pressed(0x01) and not cooldown then
                if point_in_rect(mx, my, pos_x, pos_y, width, height) then
                    if point_in_rect(mx, my, reset_x, reset_y, reset_size, reset_size) then
                        init()
                    elseif point_in_rect(mx, my, grid_start_x, grid_start_y, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE) then
                        local grid_x = math.floor((mx - grid_start_x) / CELL_SIZE) + 1
                        local grid_y = math.floor((my - grid_start_y) / CELL_SIZE) + 1
                        
                        reveal(grid_x, grid_y)
                    else
                        dragging = true
                        drag_offset_x = mx - pos_x
                        drag_offset_y = my - pos_y
                    end
                end
                
                cooldown = true
            end
            
            if not input.is_key_down(0x01) then
                cooldown = false
            end
            
            if input.is_key_pressed(0x02) then
                if point_in_rect(mx, my, grid_start_x, grid_start_y, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE) then
                    local grid_x = math.floor((mx - grid_start_x) / CELL_SIZE) + 1
                    local grid_y = math.floor((my - grid_start_y) / CELL_SIZE) + 1
                    
                    toggle_flag(grid_x, grid_y)
                end
            end
        end
        
        draw()
    end
end

math.randomseed(winapi.get_tickcount64())
init()

engine.register_on_engine_tick(tick)

engine.log("Classic Minesweeper loaded. Press Insert to toggle visibility, R to reset.", 0, 255, 0, 255)
