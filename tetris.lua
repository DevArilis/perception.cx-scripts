local visible = true

local BLOCK_SIZE = 30
local GRID_WIDTH = 10
local GRID_HEIGHT = 20
local GAME_WIDTH = GRID_WIDTH * BLOCK_SIZE
local GAME_HEIGHT = GRID_HEIGHT * BLOCK_SIZE
local SIDEBAR_WIDTH = 200

local grid = {}
local current_piece = {}
local next_piece = {}
local piece_x = 0
local piece_y = 0
local score = 0
local level = 1
local lines_cleared = 0
local game_over = false
local game_paused = false
local drop_timer = 0
local drop_speed = 1000
local soft_drop_timer = 0
local SOFT_DROP_SPEED = 80
local last_move_time = 0
local MOVE_DELAY = 80

local pos_x = 100
local pos_y = 50
local drag_offset_x = 0
local drag_offset_y = 0
local dragging = false
local fonts = {}

local tetrominoes = {
    {
        shape = {
            {0, 0, 0, 0},
            {1, 1, 1, 1},
            {0, 0, 0, 0},
            {0, 0, 0, 0}
        },
        color = {0, 240, 240, 255}
    },
    {
        shape = {
            {1, 1},
            {1, 1}
        },
        color = {240, 240, 0, 255}
    },
    {
        shape = {
            {0, 1, 0},
            {1, 1, 1},
            {0, 0, 0}
        },
        color = {160, 0, 240, 255}
    },
    {
        shape = {
            {0, 1, 1},
            {1, 1, 0},
            {0, 0, 0}
        },
        color = {0, 240, 0, 255}
    },
    {
        shape = {
            {1, 1, 0},
            {0, 1, 1},
            {0, 0, 0}
        },
        color = {240, 0, 0, 255}
    },
    {
        shape = {
            {1, 0, 0},
            {1, 1, 1},
            {0, 0, 0}
        },
        color = {0, 0, 240, 255}
    },
    {
        shape = {
            {0, 0, 1},
            {1, 1, 1},
            {0, 0, 0}
        },
        color = {240, 160, 0, 255}
    }
}

local random_tetromino
local reset_game
local init

local function is_point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

local function copy_tetromino(piece)
    local new_piece = {
        shape = {},
        color = {piece.color[1], piece.color[2], piece.color[3], piece.color[4]}
    }
    
    for i = 1, #piece.shape do
        new_piece.shape[i] = {}
        for j = 1, #piece.shape[i] do
            new_piece.shape[i][j] = piece.shape[i][j]
        end
    end
    
    return new_piece
end

function random_tetromino()
    return copy_tetromino(tetrominoes[math.random(1, #tetrominoes)])
end

local function is_valid_position(piece, x, y)
    for row = 1, #piece.shape do
        for col = 1, #piece.shape[row] do
            if piece.shape[row][col] == 1 then
                local grid_x = x + col - 1
                local grid_y = y + row - 1
                
                if grid_x < 1 or grid_x > GRID_WIDTH or grid_y < 1 or grid_y > GRID_HEIGHT then
                    return false
                end
                
                if grid[grid_y][grid_x] ~= 0 then
                    return false
                end
            end
        end
    end
    
    return true
end

local function rotate_piece(piece)
    local new_piece = copy_tetromino(piece)
    local n = #piece.shape
    
    for i = 1, n do
        for j = 1, n do
            new_piece.shape[j][n - i + 1] = piece.shape[i][j]
        end
    end
    
    return new_piece
end

local function place_piece()
    for row = 1, #current_piece.shape do
        for col = 1, #current_piece.shape[row] do
            if current_piece.shape[row][col] == 1 then
                local grid_x = piece_x + col - 1
                local grid_y = piece_y + row - 1
                
                grid[grid_y][grid_x] = {
                    color = {
                        current_piece.color[1],
                        current_piece.color[2],
                        current_piece.color[3],
                        current_piece.color[4]
                    }
                }
            end
        end
    end
    
    local completed_lines = 0
    for y = 1, GRID_HEIGHT do
        local line_complete = true
        for x = 1, GRID_WIDTH do
            if grid[y][x] == 0 then
                line_complete = false
                break
            end
        end
        
        if line_complete then
            completed_lines = completed_lines + 1
            
            for y2 = y, 2, -1 do
                for x = 1, GRID_WIDTH do
                    grid[y2][x] = grid[y2 - 1][x]
                end
            end
            
            for x = 1, GRID_WIDTH do
                grid[1][x] = 0
            end
        end
    end
    
    if completed_lines > 0 then
        local points = 0
        if completed_lines == 1 then
            points = 40 * level
        elseif completed_lines == 2 then
            points = 100 * level
        elseif completed_lines == 3 then
            points = 300 * level
        elseif completed_lines == 4 then
            points = 1200 * level
        end
        
        score = score + points
        lines_cleared = lines_cleared + completed_lines
        level = math.floor(lines_cleared / 10) + 1
        
        drop_speed = math.max(100, 1000 - (level - 1) * 100)
    end
    
    current_piece = next_piece
    next_piece = random_tetromino()
    
    piece_x = math.floor(GRID_WIDTH / 2) - math.floor(#current_piece.shape[1] / 2) + 1
    piece_y = 1
    
    if not is_valid_position(current_piece, piece_x, piece_y) then
        game_over = true
    end
end

local function move_piece(dx, dy)
    local new_x = piece_x + dx
    local new_y = piece_y + dy
    
    if is_valid_position(current_piece, new_x, new_y) then
        piece_x = new_x
        piece_y = new_y
        return true
    end
    
    if dy > 0 then
        place_piece()
    end
    
    return false
end

local function try_rotate()
    local rotated = rotate_piece(current_piece)
    
    if is_valid_position(rotated, piece_x, piece_y) then
        current_piece = rotated
        return true
    end
    
    for offset = 1, 2 do
        if is_valid_position(rotated, piece_x + offset, piece_y) then
            current_piece = rotated
            piece_x = piece_x + offset
            return true
        end
        
        if is_valid_position(rotated, piece_x - offset, piece_y) then
            current_piece = rotated
            piece_x = piece_x - offset
            return true
        end
        
        if is_valid_position(rotated, piece_x, piece_y - offset) then
            current_piece = rotated
            piece_y = piece_y - offset
            return true
        end
    end
    
    return false
end

local function hard_drop()
    while move_piece(0, 1) do
    end
end

function reset_game()
    grid = {}
    for y = 1, GRID_HEIGHT do
        grid[y] = {}
        for x = 1, GRID_WIDTH do
            grid[y][x] = 0
        end
    end
    
    score = 0
    level = 1
    lines_cleared = 0
    game_over = false
    game_paused = false
    drop_timer = winapi.get_tickcount64()
    drop_speed = 1000
    soft_drop_timer = winapi.get_tickcount64()
    last_move_time = winapi.get_tickcount64()
    
    current_piece = random_tetromino()
    next_piece = random_tetromino()
    
    piece_x = math.floor(GRID_WIDTH / 2) - math.floor(#current_piece.shape[1] / 2) + 1
    piece_y = 1
end

function init()
    fonts.small = render.create_font("Arial", 14, 700)
    fonts.medium = render.create_font("Arial", 20, 700)
    fonts.large = render.create_font("Arial", 30, 700)
    
    local viewport_w, viewport_h = render.get_viewport_size()
    pos_x = math.floor((viewport_w - (GAME_WIDTH + SIDEBAR_WIDTH)) / 2)
    pos_y = math.floor((viewport_h - GAME_HEIGHT) / 2)
    
    reset_game()
end

local function draw_block(x, y, color)
    render.draw_rectangle(
        x, 
        y, 
        BLOCK_SIZE, 
        BLOCK_SIZE, 
        color[1], color[2], color[3], color[4], 
        0, 
        true
    )
    
    render.draw_line(
        x, 
        y, 
        x + BLOCK_SIZE, 
        y, 
        math.min(255, color[1] + 60), 
        math.min(255, color[2] + 60), 
        math.min(255, color[3] + 60), 
        color[4], 
        2
    )
    
    render.draw_line(
        x, 
        y, 
        x, 
        y + BLOCK_SIZE, 
        math.min(255, color[1] + 60), 
        math.min(255, color[2] + 60), 
        math.min(255, color[3] + 60), 
        color[4], 
        2
    )
    
    render.draw_line(
        x + BLOCK_SIZE, 
        y, 
        x + BLOCK_SIZE, 
        y + BLOCK_SIZE, 
        math.max(0, color[1] - 60), 
        math.max(0, color[2] - 60), 
        math.max(0, color[3] - 60), 
        color[4], 
        2
    )
    
    render.draw_line(
        x, 
        y + BLOCK_SIZE, 
        x + BLOCK_SIZE, 
        y + BLOCK_SIZE, 
        math.max(0, color[1] - 60), 
        math.max(0, color[2] - 60), 
        math.max(0, color[3] - 60), 
        color[4], 
        2
    )
    
    render.draw_rectangle(
        x + 3, 
        y + 3, 
        BLOCK_SIZE - 6, 
        BLOCK_SIZE - 6, 
        math.min(255, color[1] + 30), 
        math.min(255, color[2] + 30), 
        math.min(255, color[3] + 30), 
        color[4], 
        0, 
        true
    )
end

local function draw_game()
    if not visible then
        return
    end
    
    local total_width = GAME_WIDTH + SIDEBAR_WIDTH
    
    render.draw_rectangle(
        pos_x, 
        pos_y, 
        total_width, 
        GAME_HEIGHT, 
        30, 30, 30, 255, 
        1, 
        true
    )
    
    render.draw_rectangle(
        pos_x, 
        pos_y, 
        GAME_WIDTH, 
        GAME_HEIGHT, 
        0, 0, 0, 255, 
        1, 
        true
    )
    
    for x = 0, GRID_WIDTH do
        render.draw_line(
            pos_x + x * BLOCK_SIZE, 
            pos_y, 
            pos_x + x * BLOCK_SIZE, 
            pos_y + GAME_HEIGHT, 
            50, 50, 50, 255, 
            1
        )
    end
    
    for y = 0, GRID_HEIGHT do
        render.draw_line(
            pos_x, 
            pos_y + y * BLOCK_SIZE, 
            pos_x + GAME_WIDTH, 
            pos_y + y * BLOCK_SIZE, 
            50, 50, 50, 255, 
            1
        )
    end
    
    for y = 1, GRID_HEIGHT do
        for x = 1, GRID_WIDTH do
            if grid[y][x] ~= 0 then
                draw_block(
                    pos_x + (x - 1) * BLOCK_SIZE, 
                    pos_y + (y - 1) * BLOCK_SIZE, 
                    grid[y][x].color
                )
            end
        end
    end
    
    if not game_over and not game_paused then
        for row = 1, #current_piece.shape do
            for col = 1, #current_piece.shape[row] do
                if current_piece.shape[row][col] == 1 then
                    draw_block(
                        pos_x + (piece_x + col - 2) * BLOCK_SIZE, 
                        pos_y + (piece_y + row - 2) * BLOCK_SIZE, 
                        current_piece.color
                    )
                end
            end
        end
    end
    
    local sidebar_x = pos_x + GAME_WIDTH
    
    render.draw_rectangle(
        sidebar_x, 
        pos_y, 
        SIDEBAR_WIDTH, 
        GAME_HEIGHT, 
        40, 40, 40, 255, 
        1, 
        true
    )
    
    render.draw_text(
        fonts.medium,
        "Next:",
        sidebar_x + 20,
        pos_y + 20,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    local preview_x = sidebar_x + 50
    local preview_y = pos_y + 60
    
    render.draw_rectangle(
        preview_x, 
        preview_y, 
        4 * BLOCK_SIZE, 
        4 * BLOCK_SIZE, 
        0, 0, 0, 255, 
        1, 
        true
    )
    
    local offset_x = math.floor((4 - #next_piece.shape[1]) / 2)
    local offset_y = math.floor((4 - #next_piece.shape) / 2)
    
    for row = 1, #next_piece.shape do
        for col = 1, #next_piece.shape[row] do
            if next_piece.shape[row][col] == 1 then
                draw_block(
                    preview_x + (offset_x + col - 1) * BLOCK_SIZE, 
                    preview_y + (offset_y + row - 1) * BLOCK_SIZE, 
                    next_piece.color
                )
            end
        end
    end
    
    render.draw_text(
        fonts.medium,
        "Score:",
        sidebar_x + 20,
        pos_y + 180,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.medium,
        tostring(score),
        sidebar_x + 20,
        pos_y + 210,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.medium,
        "Level:",
        sidebar_x + 20,
        pos_y + 250,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.medium,
        tostring(level),
        sidebar_x + 20,
        pos_y + 280,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.medium,
        "Lines:",
        sidebar_x + 20,
        pos_y + 320,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.medium,
        tostring(lines_cleared),
        sidebar_x + 20,
        pos_y + 350,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Controls:",
        sidebar_x + 20,
        pos_y + 400,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Left/Right : Move",
        sidebar_x + 20,
        pos_y + 430,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Up : Rotate",
        sidebar_x + 20,
        pos_y + 450,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Down : Soft Drop",
        sidebar_x + 20,
        pos_y + 470,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Space : Hard Drop",
        sidebar_x + 20,
        pos_y + 490,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "P : Pause",
        sidebar_x + 20,
        pos_y + 510,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "R : Restart",
        sidebar_x + 20,
        pos_y + 530,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    render.draw_text(
        fonts.small,
        "Insert : Hide/Show",
        sidebar_x + 20,
        pos_y + 550,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
    
    if game_over then
        render.draw_rectangle(
            pos_x, 
            pos_y + GAME_HEIGHT / 2 - 50, 
            GAME_WIDTH, 
            100, 
            0, 0, 0, 200, 
            1, 
            true
        )
        
        render.draw_text(
            fonts.large,
            "GAME OVER",
            pos_x + 35,
            pos_y + GAME_HEIGHT / 2 - 40,
            255, 255, 255, 255,
            0, 0, 0, 0, 0
        )
        
        render.draw_text(
            fonts.medium,
            "Press R to restart",
            pos_x + 65,
            pos_y + GAME_HEIGHT / 2 + 10,
            255, 255, 255, 255,
            0, 0, 0, 0, 0
        )
    end
    
    if game_paused then
        render.draw_rectangle(
            pos_x, 
            pos_y + GAME_HEIGHT / 2 - 50, 
            GAME_WIDTH, 
            100, 
            0, 0, 0, 200, 
            1, 
            true
        )
        
        render.draw_text(
            fonts.large,
            "PAUSED",
            pos_x + 85,
            pos_y + GAME_HEIGHT / 2 - 20,
            255, 255, 255, 255,
            0, 0, 0, 0, 0
        )
    end
end

local function update_game()
    if game_over or game_paused then
        return
    end
    
    local current_time = winapi.get_tickcount64()
    if current_time - drop_timer >= drop_speed then
        drop_timer = current_time
        move_piece(0, 1)
    end
    
    if input.is_key_down(0x28) then
        if current_time - soft_drop_timer >= SOFT_DROP_SPEED then
            soft_drop_timer = current_time
            move_piece(0, 1)
        end
    end
end

local function handle_keys()
    local current_time = winapi.get_tickcount64()
    
    if input.is_key_pressed(0x2D) then
        visible = not visible
    end
    
    if input.is_key_pressed(0x52) then
        reset_game()
    end
    
    if input.is_key_pressed(0x50) then
        game_paused = not game_paused
    end
    
    if not game_over and not game_paused then
        if current_time - last_move_time >= MOVE_DELAY then
            if input.is_key_down(0x25) then
                move_piece(-1, 0)
                last_move_time = current_time
            end
            
            if input.is_key_down(0x27) then
                move_piece(1, 0)
                last_move_time = current_time
            end
        end
        
        if input.is_key_pressed(0x26) then
            try_rotate()
        end
        
        if input.is_key_pressed(0x20) then
            hard_drop()
        end
    end
end

local function tick()
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
            if input.is_key_pressed(0x01) then
                local total_width = GAME_WIDTH + SIDEBAR_WIDTH
                if is_point_in_rect(mx, my, pos_x, pos_y, total_width, GAME_HEIGHT) then
                    dragging = true
                    drag_offset_x = mx - pos_x
                    drag_offset_y = my - pos_y
                end
            end
        end
        
        handle_keys()
        update_game()
        draw_game()
    end
end

math.randomseed(winapi.get_tickcount64())
init()

engine.register_on_engine_tick(tick)

engine.log("Tetris loaded. Press Insert to toggle visibility, arrow keys to play.", 0, 255, 0, 255)
