local visible = true

local logo_width = 160
local logo_height = 70
local logo_x = 0
local logo_y = 0
local speed = 0.5

local logo_color = {0, 130, 198, 255} -- DVD logo blue color
local screen_width = 0
local screen_height = 0

local corner_hits = 0
local font = nil
local logo_bitmap = nil

local function try_load_logo()
    -- Try to load the DVD logo from the URL
    logo_bitmap = render.create_bitmap_from_url("https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/DVD_logo.svg/2560px-DVD_logo.svg.png")
    return logo_bitmap ~= nil
end

local function draw_simplified_logo(x, y, width, height)
    -- Draw a simplified DVD logo
    local d_start_x = x + width * 0.15
    local d_width = width * 0.2
    local v_start_x = x + width * 0.4
    local v_width = width * 0.2
    local d2_start_x = x + width * 0.65
    local d2_width = width * 0.2
    
    -- Draw 'D'
    render.draw_rectangle(d_start_x, y + height * 0.2, d_width * 0.2, height * 0.6, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d_start_x, y + height * 0.2, d_width, height * 0.1, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d_start_x, y + height * 0.7, d_width, height * 0.1, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d_start_x + d_width * 0.8, y + height * 0.3, d_width * 0.2, height * 0.4, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    
    -- Draw 'V'
    render.draw_line(v_start_x, y + height * 0.2, v_start_x + v_width/2, y + height * 0.8, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 3)
    render.draw_line(v_start_x + v_width/2, y + height * 0.8, v_start_x + v_width, y + height * 0.2, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 3)
    
    -- Draw second 'D'
    render.draw_rectangle(d2_start_x, y + height * 0.2, d2_width * 0.2, height * 0.6, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d2_start_x, y + height * 0.2, d2_width, height * 0.1, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d2_start_x, y + height * 0.7, d2_width, height * 0.1, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
    render.draw_rectangle(d2_start_x + d2_width * 0.8, y + height * 0.3, d2_width * 0.2, height * 0.4, logo_color[1], logo_color[2], logo_color[3], logo_color[4], 2, true)
end

local function draw_dvd_logo()
    if not visible then
        return
    end

    -- Draw the logo
    if logo_bitmap then
        -- If we successfully loaded the bitmap, draw it
        render.draw_bitmap(logo_bitmap, logo_x, logo_y, logo_width, logo_height, 255)
    else
        -- Otherwise draw our simplified logo
        draw_simplified_logo(logo_x, logo_y, logo_width, logo_height)
    end
    
    -- Draw corner hit counter (small and unobtrusive)
    render.draw_text(
        font,
        "Corner Hits: " .. corner_hits,
        10,
        10,
        255, 255, 255, 255,
        0, 0, 0, 0, 0
    )
end

local function update_logo()
    -- Get current screen dimensions in case they changed
    screen_width, screen_height = render.get_viewport_size()
    
    -- Update position
    local new_x = logo_x + speed
    local new_y = logo_y + speed
    
    -- Check boundaries and handle collision
    if new_x <= 0 or new_x + logo_width >= screen_width then
        speed = -speed
        
        if new_x <= 0 then
            new_x = 0
        else
            new_x = screen_width - logo_width
        end
    end
    
    if new_y <= 0 or new_y + logo_height >= screen_height then
        speed = -speed
        
        if new_y <= 0 then
            new_y = 0
        else
            new_y = screen_height - logo_height
        end
    end
    
    -- Check for perfect corner hits
    if ((math.abs(new_x) < 0.5 and math.abs(new_y) < 0.5) or
        (math.abs(new_x) < 0.5 and math.abs(new_y + logo_height - screen_height) < 0.5) or
        (math.abs(new_x + logo_width - screen_width) < 0.5 and math.abs(new_y) < 0.5) or
        (math.abs(new_x + logo_width - screen_width) < 0.5 and math.abs(new_y + logo_height - screen_height) < 0.5)) then
        corner_hits = corner_hits + 1
    end
    
    logo_x = new_x
    logo_y = new_y
end

local function init()
    -- Initialize font
    font = render.create_font("Arial", 16, 700)
    
    -- Get screen dimensions
    screen_width, screen_height = render.get_viewport_size()
    
    -- Initialize logo position randomly
    logo_x = math.random(0, screen_width - logo_width)
    logo_y = math.random(0, screen_height - logo_height)
    
    -- Try to load the logo bitmap
    try_load_logo()
end

local function tick()
    -- Toggle visibility with Insert key
    if input.is_key_pressed(0x2D) then -- Insert key
        visible = not visible
    end
    
    if visible then
        -- Update logo position
        update_logo()
        
        -- Draw DVD logo
        draw_dvd_logo()
    end
end

-- Initialize with random seed
math.randomseed(winapi.get_tickcount64())
init()

-- Register tick handler
engine.register_on_engine_tick(tick)

-- Display startup message
engine.log("DVD Logo Bouncer loaded. Press Insert to toggle visibility.", 0, 255, 0, 255)
