module top(
    input basys_clock,
    input uart_rx,    // From ESP 32, which is connected to XBox controller.
    input [15:0] sw,  // sw[15] is developer mode
    output [7:0] JB,  // OLED signals
    output [3:0] an,
    output [6:0] seg,
    output [15:0] led
);

    //---------------------------------------------------
    // Clock Generation
    //---------------------------------------------------
    wire clk6p25;
    clock slow_clock(basys_clock, 7, clk6p25);
    
    wire clk100hz;
    clock clk100(basys_clock, 32'd500000, clk100hz);

    //---------------------------------------------------
    // OLED Display Signals & Coordinates
    //---------------------------------------------------
    wire fb;
    wire [12:0] pixel_index;
    wire sendpixel, samplepixel;
    
    wire [7:0] x_coord = pixel_index % 96;
    wire [7:0] y_coord = pixel_index / 96;
        
    //---------------------------------------------------
    // Controller Input
    //---------------------------------------------------
    wire btnL; // Left
    wire btnR; // Right
    wire btnU; // Up
    wire btnD; // Down
    wire jumpBtn; // Jump
    wire dashBtn; // Dash
    wire playOrReplayBtn; // Y on Xbox
    wire controllerConnected;
    wire start = playOrReplayBtn;
    
    controller_input ctlr(basys_clock, uart_rx, btnL, btnR, btnU, btnD, jumpBtn, dashBtn, playOrReplayBtn, controllerConnected);
    
    //---------------------------------------------------
    // Dash Availability (The Dash Effect)
    //---------------------------------------------------
    dash_input_controller d_ctlr(clk100hz, basys_clock, btnL, btnR, dashBtn, led[15:0]);
    
    //---------------------------------------------------
    // Deaths Counter
    //---------------------------------------------------
    wire death_reset;
    reg death_increment = 0;
    reg death_increment_old = 0;
    reg [13:0] deaths = 0;
    reg old_death_increment = 0;
        
    death_counter dc(basys_clock, deaths, an, seg);
    
    always @(posedge clk100hz) begin
        if (death_reset) begin
            deaths <= 0;
        end else begin
            if (death_increment && old_death_increment != death_increment) begin
                deaths <= deaths + 1;
                old_death_increment <= 1;
            end
            if (death_increment == 0 && old_death_increment != death_increment) begin
                old_death_increment <= 0;
            end
        end
    end
    
    //---------------------------------------------------
    // Background FSM & Developer Mode Logic
    //---------------------------------------------------
    localparam STATE_IDLE    = 2'b00;
    localparam STATE_ANIMATE = 2'b01;
    localparam STATE_FADE    = 2'b10;
    localparam STATE_WAIT    = 2'b11;

    reg [1:0] transition_state = STATE_IDLE;
    reg [3:0] anim_frame = 0;
    reg [7:0] anim_timer = 0;
    localparam ANIM_FRAME_DURATION = 20;
    reg [6:0] fade_factor = 0;
    localparam FADE_MAX = 64;
    reg [1:0] wait_counter = 0;

    localparam MAX_LEVEL = 4;
    reg [2:0] current_bg = 0;
    reg [2:0] desired_bg = 0;

    reg start_prev = 0;
    wire start_edge = start & ~start_prev;

    wire [2:0] dev_switch_count;
    assign dev_switch_count = sw[14] + sw[0] + sw[1] + sw[2] + sw[3] + sw[4];

    wire game_active = (current_bg >= 1 && current_bg <= 4);
    assign death_reset = (current_bg == 1) ? 1 : 0;
    wire [1:0] lvl;
    assign lvl = (current_bg > 0) ? (current_bg - 1) : 0;
    
    wire level_done = game_active && is_lvldone(player_x, player_y, lvl);

    always @(posedge clk6p25) begin
        start_prev <= start;
        if (transition_state == STATE_IDLE) begin
            if (level_done) begin
                if (current_bg == 4) begin
                    desired_bg <= 5;
                    fade_factor <= 0;
                    transition_state <= STATE_FADE;
                end else if (current_bg >= 1 && current_bg < 4) begin
                    desired_bg <= current_bg + 1;
                    fade_factor <= 0;
                    transition_state <= STATE_FADE;
                end else begin
                    desired_bg <= 0;
                    fade_factor <= 0;
                    transition_state <= STATE_FADE;
                end
            end else if (current_bg == 5 && playOrReplayBtn) begin
                desired_bg <= 1;
                fade_factor <= 0;
                transition_state <= STATE_FADE;
            end else if (sw[15]) begin
                if (dev_switch_count == 1) begin
                    if (sw[14] && (current_bg != 0)) begin
                        desired_bg <= 0;
                        transition_state <= STATE_FADE;
                        fade_factor <= 0;
                    end else if (sw[0] && (current_bg != 1)) begin
                        desired_bg <= 1;
                        if (current_bg == 0) begin
                            transition_state <= STATE_ANIMATE;
                            anim_frame <= 0;
                            anim_timer <= 0;
                        end else begin
                            transition_state <= STATE_FADE;
                            fade_factor <= 0;
                        end
                    end else if (sw[1] && (current_bg != 2)) begin
                        desired_bg <= 2;
                        if (current_bg == 0) begin
                            transition_state <= STATE_ANIMATE;
                            anim_frame <= 0;
                            anim_timer <= 0;
                        end else begin
                            transition_state <= STATE_FADE;
                            fade_factor <= 0;
                        end
                    end else if (sw[2] && (current_bg != 3)) begin
                        desired_bg <= 3;
                        if (current_bg == 0) begin
                            transition_state <= STATE_ANIMATE;
                            anim_frame <= 0;
                            anim_timer <= 0;
                        end else begin
                            transition_state <= STATE_FADE;
                            fade_factor <= 0;
                        end
                    end else if (sw[3] && (current_bg != 4)) begin
                        desired_bg <= 4;
                        if (current_bg == 0) begin
                            transition_state <= STATE_ANIMATE;
                            anim_frame <= 0;
                            anim_timer <= 0;
                        end else begin
                            transition_state <= STATE_FADE;
                            fade_factor <= 0;
                        end
                    end else if (sw[4] && (current_bg != 5)) begin
                        desired_bg <= 5;
                        transition_state <= STATE_FADE;
                        fade_factor <= 0;
                    end
                end
            end else if (current_bg == 0 && playOrReplayBtn) begin
                desired_bg <= 1;
                transition_state <= STATE_ANIMATE;
                anim_frame <= 0;
                anim_timer <= 0;
            end
        end else if (transition_state == STATE_ANIMATE) begin
            if (fb) begin
                if (anim_timer < ANIM_FRAME_DURATION - 1)
                    anim_timer <= anim_timer + 1;
                else begin
                    anim_timer <= 0;
                    if (anim_frame < 8)
                        anim_frame <= anim_frame + 1;
                    else begin
                        transition_state <= STATE_FADE;
                        fade_factor <= 0;
                    end
                end
            end
        end else if (transition_state == STATE_FADE) begin
            if (fb) begin
                if (fade_factor < FADE_MAX)
                    fade_factor <= fade_factor + 1;
                else begin
                    current_bg <= desired_bg;
                    transition_state <= STATE_WAIT;
                    wait_counter <= 0;
                end
            end
        end else if (transition_state == STATE_WAIT) begin
            if (fb) begin
                if (wait_counter < 2)
                    wait_counter <= wait_counter + 1;
                else
                    transition_state <= STATE_IDLE;
            end
        end
    end

    //---------------------------------------------------
    // Image ROMs for Backgrounds & Animations
    //---------------------------------------------------
    wire [15:0] menu_data, flash_data, pink_data, blue_data;
    image_rom #(.MEMFILE("menu.mem"))      menuROM(.clk(clk6p25), .addr(pixel_index), .data(menu_data));
    image_rom #(.MEMFILE("flash_menu.mem")) flashROM(.clk(clk6p25), .addr(pixel_index), .data(flash_data));
    image_rom #(.MEMFILE("pink_menu.mem"))   pinkROM(.clk(clk6p25), .addr(pixel_index), .data(pink_data));
    image_rom #(.MEMFILE("blued_menu.mem"))   blueROM(.clk(clk6p25), .addr(pixel_index), .data(blue_data));
    
    wire [15:0] endscreen_data;
    image_rom #(.MEMFILE("endscreen.mem")) endscreenROM (.clk(clk6p25), .addr(pixel_index), .data(endscreen_data));
    
    wire [15:0] bg1_data, bg2_data, bg3_data, bg4_data;
    image_rom #(.MEMFILE("lvl0.mem")) bg1ROM(.clk(clk6p25), .addr(pixel_index), .data(bg1_data));
    image_rom #(.MEMFILE("lvl1.mem")) bg2ROM(.clk(clk6p25), .addr(pixel_index), .data(bg2_data));
    image_rom #(.MEMFILE("lvl2.mem")) bg3ROM(.clk(clk6p25), .addr(pixel_index), .data(bg3_data));
    image_rom #(.MEMFILE("lvl3.mem")) bg4ROM(.clk(clk6p25), .addr(pixel_index), .data(bg4_data));
    
    wire [15:0] src_data = (current_bg == 0) ? menu_data :
                           (current_bg == 1) ? bg1_data :
                           (current_bg == 2) ? bg2_data :
                           (current_bg == 3) ? bg3_data :
                           (current_bg == 4) ? bg4_data :
                           (current_bg == 5) ? endscreen_data : menu_data;
    wire [15:0] tgt_data = (desired_bg == 0) ? menu_data :
                           (desired_bg == 1) ? bg1_data :
                           (desired_bg == 2) ? bg2_data :
                           (desired_bg == 3) ? bg3_data :
                           (desired_bg == 4) ? bg4_data :
                           (desired_bg == 5) ? endscreen_data : menu_data;
    wire [4:0] src_R = src_data[15:11];
    wire [5:0] src_G = src_data[10:5];
    wire [4:0] src_B = src_data[4:0];
    wire [4:0] tgt_R = tgt_data[15:11];
    wire [5:0] tgt_G = tgt_data[10:5];
    wire [4:0] tgt_B = tgt_data[4:0];
    wire [12:0] blend_R_temp = (src_R * (FADE_MAX - fade_factor)) + (tgt_R * fade_factor);
    wire [13:0] blend_G_temp = (src_G * (FADE_MAX - fade_factor)) + (tgt_G * fade_factor);
    wire [12:0] blend_B_temp = (src_B * (FADE_MAX - fade_factor)) + (tgt_B * fade_factor);
    wire [4:0] final_R = blend_R_temp >> 6;
    wire [5:0] final_G = blend_G_temp >> 6;
    wire [4:0] final_B = blend_B_temp >> 6;
    wire [15:0] fade_pixel = {final_R, final_G, final_B};

    reg [15:0] pixel_data_out;
    always @(*) begin
        case (transition_state)
            STATE_IDLE: begin
                case (current_bg)
                    0: pixel_data_out = menu_data;
                    1: pixel_data_out = bg1_data;
                    2: pixel_data_out = bg2_data;
                    3: pixel_data_out = bg3_data;
                    4: pixel_data_out = bg4_data;
                    5: pixel_data_out = endscreen_data;
                    default: pixel_data_out = menu_data;
                endcase
            end
            STATE_ANIMATE: begin
                case (anim_frame)
                    0, 2, 4: pixel_data_out = menu_data;
                    1, 3, 5: pixel_data_out = flash_data;
                    6:       pixel_data_out = pink_data;
                    7:       pixel_data_out = blue_data;
                    8:       pixel_data_out = 16'h0000;
                    default: pixel_data_out = menu_data;
                endcase
            end
            STATE_FADE: pixel_data_out = fade_pixel;
            STATE_WAIT: pixel_data_out = tgt_data;
            default:    pixel_data_out = menu_data;
        endcase
    end

    //---------------------------------------------------
    // Raining Background Layer with Fade Effect
    //---------------------------------------------------
    reg [15:0] rain_offset_fp = 0;
    always @(posedge clk6p25) begin
        if (fb)
            rain_offset_fp <= rain_offset_fp + 16'd96;
    end
    wire [7:0] rain_offset_int = rain_offset_fp[15:8];
    
    wire [7:0] sum_xy = y_coord + x_coord;
    wire [7:0] f_val = x_coord;
    wire [1:0] rain_color_index = sum_xy % 3;
    wire [15:0] rain_color = (rain_color_index == 0) ? 16'h001F :
                             (rain_color_index == 1) ? 16'h07FF :
                                                      16'hFFFF;
    wire [11:0] blended_rain_R_temp = rain_color[15:11] * fade_factor;
    wire [12:0] blended_rain_G_temp = rain_color[10:5] * fade_factor;
    wire [11:0] blended_rain_B_temp = rain_color[4:0] * fade_factor;
    wire [4:0] final_rain_R = blended_rain_R_temp >> 6;
    wire [5:0] final_rain_G = blended_rain_G_temp >> 6;
    wire [4:0] final_rain_B = blended_rain_B_temp >> 6;
    wire [15:0] faded_rain_color = {final_rain_R, final_rain_G, final_rain_B};
    wire [15:0] effective_rain_color = (transition_state == STATE_FADE) ? faded_rain_color : rain_color;
    wire base_drop = (sum_xy % 10 == 0) && ((f_val + rain_offset_int) % 20 == 0);
    wire next_drop = (x_coord < 95 && y_coord > 0) &&
                     (sum_xy % 10 == 0) && (((f_val + 1) + rain_offset_int) % 20 == 0);
    wire is_splash = base_drop && ((sum_xy / 10) % 3 == 0);
    wire drop_active;
    assign drop_active = is_splash ? 
                         (base_drop || 
                          (x_coord > 0 && base_drop_at(x_coord + 1, y_coord)) || 
                          (y_coord < 63 && base_drop_at(x_coord, y_coord - 1)) || 
                          (x_coord > 0 && y_coord < 63 && base_drop_at(x_coord + 1, y_coord - 1))) :
                         (base_drop || next_drop);
    function base_drop_at(input [6:0] x, input [6:0] y);
        begin
            base_drop_at = (((y + x) % 10) == 0) && (((x + rain_offset_int) % 20) == 0);
        end
    endfunction
    wire [15:0] background_with_rain = drop_active ? effective_rain_color : pixel_data_out;

    //---------------------------------------------------
    // Sprite Explosion & Player Movement, Level Reset (clk100hz)
    //---------------------------------------------------
    reg [7:0] player_x;
    reg [11:0] y_pos_fp; // Fixed-point y-position (8-bit integer, 4-bit fraction)
    reg signed [7:0] vy = 0; // Vertical velocity (pixels per frame, 4-bit fraction)
    reg [7:0] player_y; // Integer y-position

    localparam GRAVITY = 1;      // Gravity acceleration: 0.125 pixels/frame^2
    localparam JUMP_SPEED = 20;  // Initial jump velocity: 2 pixels/frame upward
    
    reg [1:0] prev_lvl = 0;
    reg prev_game_active = 0;
    reg facing = 0;
    reg [7:0] obs;
    
    localparam SPRITE_NORMAL  = 2'b00;
    localparam SPRITE_EXPLODE = 2'b01;
    localparam SPRITE_BLINK   = 2'b10;
    
    reg [1:0] sprite_state = SPRITE_NORMAL;
    reg [3:0] explosion_frame = 0;
    reg [7:0] explosion_timer = 0;
    localparam EXPLOSION_FRAME_DURATION = 10;
    localparam MAX_EXPLOSION_FRAME = 8;
    localparam BLINK_DURATION = 200;
    reg [7:0] blink_timer = 0;
    reg blink_visible = 1'b1;
    
    localparam TRANSITION_BLINK_DURATION = 100;
    reg blink_for_transition = 0;
    
    reg [1:0] transition_sync;
    always @(posedge clk100hz) begin
        transition_sync <= transition_state;
    end
    wire freeze_sprite = (transition_sync != STATE_IDLE);
    
    reg freeze_sprite_prev = 0;
    reg first_game_start = 1'b1;
    
    wire reset_player;
    assign reset_player = start ||
                          (lvl != prev_lvl) ||
                          is_lvldone(player_x, player_y, lvl) ||
                          (!prev_game_active && game_active);
                          
    reg on_platform;
    reg [11:0] y_pos_fp_new;
    reg [7:0] new_obs;
    
    // New dash state registers:
    reg dashing;                     // 1 when dash is active
    reg [3:0] dash_counter;          // counts remaining dash update cycles
    reg signed [7:0] dash_dx;        // per-cycle dash horizontal displacement
    reg signed [7:0] dash_dy;        // per-cycle dash vertical displacement
    
    // last_direction: {up, upright, right, downright, down, downleft, left, upleft}
    reg [3:0] last_direction;
    reg signed [7:0] dash_new_x;
    reg signed [7:0] dash_new_y;
    
    // Registers for dash button edge-detection and dash availability.
    reg dash_ready;      // becomes 1 when Celeste is on the ground/platform
    reg btnJump;
    reg btnDash;
    reg btnDash_prev;    // previous state of btnDash
    
    reg [7:0] obs_dash;
   
    always @(posedge basys_clock) begin
        btnJump <= jumpBtn;
        btnDash <= dashBtn;   
    end
    
    // Dash parameters
    parameter DASH_DISTANCE = 120;    // total dash displacement (pixels)
    parameter DASH_DURATION = 20;     // dash lasts 2 update cycles
    // (Per-cycle dash displacement is determined by dash_dx/dash_dy, e.g., 5 pixels per update)
    parameter DASH_UPDATE = DASH_DISTANCE / DASH_DURATION;
    reg [31:0] counter_v = 0;
    parameter UPDATE_THRESHOLD_V = 10'd200;  // vertical update rate
    
    // Sprite movement, explosion, and blink state machine
    always @(posedge clk100hz) begin
        // Transition completion detection
        if (freeze_sprite_prev && !freeze_sprite) begin
            case (lvl)
                0: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                1: begin player_x <= 3; y_pos_fp <= (52 << 4); vy <= 0; player_y <= 8'd52; end
                2: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                3: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                default: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
            endcase
            sprite_state <= SPRITE_BLINK;
            blink_timer <= 0;
            blink_visible <= 1;
            blink_for_transition <= 1;
            dashing      <= 0;
            dash_counter <= 0;
            dash_ready   <= 1;         // Reset dash availability on reset
        end

        if (game_active) begin
            case (sprite_state)
                SPRITE_NORMAL: begin
                    if (is_dead(player_x, player_y, lvl)) begin
                        sprite_state <= SPRITE_EXPLODE;
                        explosion_frame <= 0;
                        explosion_timer <= 0;
                        death_increment <= 1;
                    end else begin
                        death_increment <= 0;
                        if (reset_player) begin
                            case (lvl)
                                0: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                1: begin player_x <= 3; y_pos_fp <= (52 << 4); vy <= 0; player_y <= 8'd52; end
                                2: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                3: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                default: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                            endcase
                        end else if (!freeze_sprite) begin
                            // --- Exclusive Dash Movement vs. Normal Physics Update ---
                            if (dashing) begin
                                if (dash_counter) begin
                                    dash_new_x = player_x + dash_dx;
                                    dash_new_y = player_y + dash_dy;
                                    obs_dash   = is_obstructed(dash_new_x, dash_new_y, lvl);
                                    if ( (dash_dx > 0 && dash_dy < 0 && obs_dash[6]) ||  // up-right
                                         (dash_dx < 0 && dash_dy < 0 && obs_dash[0]) ||  // up-left
                                         (dash_dx > 0 && dash_dy > 0 && obs_dash[4])  ||  // down-right
                                         (dash_dx < 0 && dash_dy > 0 && obs_dash[2])  ||  // down-left
                                         (dash_dx > 0 && obs_dash[5])   ||  // right
                                         (dash_dx < 0 && obs_dash[1])   ||  // left
                                         (dash_dy > 0 && obs_dash[3])   ||  // down
                                         (dash_dy < 0 && obs_dash[7])       // up
                                       ) begin
                                        // Collision encountered during dash: cancel dash.
                                        dashing <= 0;
                                        obs = is_obstructed(player_x, player_y, lvl);
                                        if (!obs[3]) begin
                                            on_platform <= 0;
                                            counter_v <= 0;
                                        end
                                    end else begin
                                        // Update position exclusively using dash displacement.
                                        player_x <= dash_new_x;
                                        player_y <= dash_new_y;
                                        y_pos_fp <= {dash_new_y, 4'b0000};
                                        dash_counter <= dash_counter - 1;
                                    end
                                end else begin
                                    // Dash duration completed.
                                    dashing <= 0;
                                    obs = is_obstructed(player_x, player_y, lvl);
                                    if (!obs[3]) begin
                                        on_platform <= 0;
                                        counter_v <= UPDATE_THRESHOLD_V;
                                    end
                                end

                            end else begin
                                // -- Normal Physics Update --
                                obs = is_obstructed(player_x, player_y, lvl);
                                on_platform = obs[3];
                                if (on_platform)
                                    dash_ready <= 1;
                                // Jumping logic: allow jump only when on a platform.
                                if (jumpBtn && on_platform) begin
                                    vy <= -JUMP_SPEED; // First upward propulsion.
                                end
                                // Horizontal movement.
                                if (btnR && !obs[5]) begin
                                    player_x <= player_x + 1;
                                    facing <= 0;
                                end else if (btnL && !obs[1]) begin
                                    player_x <= player_x - 1;
                                    facing <= 1;
                                end
                                // Apply gravity if not on platform.
                                if (!on_platform) begin
                                    vy <= vy + GRAVITY;
                                end
                                // Update vertical fixed-point and integer positions.
                                y_pos_fp_new = y_pos_fp + {{4{vy[7]}}, vy};
                                y_pos_fp <= y_pos_fp_new;
                                player_y <= y_pos_fp_new[11:4];
                                // Handle collisions.
                                new_obs = is_obstructed(player_x, y_pos_fp_new[11:4], lvl);
                                if (vy > 0 && new_obs[3]) begin
                                    vy <= 0;
                                end
                                if (vy < 0 && new_obs[7]) begin
                                    vy <= 0;
                                end
                                // --- Dash Trigger ---
                                if (btnDash && !btnDash_prev && dash_ready) begin
                                    // Disallow any leftward dash if at the starting position (player_x == 3)
                                    if ((player_x == 3) && ((btnL && !btnR) || (btnU && btnL && !btnR) || (btnD && btnL && !btnR))) begin
                                        // Suppress dash when at starting position to avoid unintended respawn or level change.
                                    end else begin
                                        if (btnU && btnR) begin           // Up-Right
                                            dash_dx <= DASH_UPDATE;
                                            dash_dy <= -DASH_UPDATE;
                                            last_direction <= 6;
                                        end else if (btnU && btnL) begin  // Up-Left
                                            dash_dx <= -DASH_UPDATE;
                                            dash_dy <= -DASH_UPDATE;
                                            last_direction <= 0;
                                        end else if (btnD && btnR) begin  // Down-Right
                                            dash_dx <= DASH_UPDATE;
                                            dash_dy <= DASH_UPDATE;
                                            last_direction <= 4;
                                        end else if (btnD && btnL) begin  // Down-Left
                                            dash_dx <= -DASH_UPDATE;
                                            dash_dy <= DASH_UPDATE;
                                            last_direction <= 2;
                                        end else if (btnU) begin          // Up
                                            dash_dx <= 0;
                                            dash_dy <= -DASH_UPDATE;
                                            last_direction <= 7;
                                        end else if (btnR) begin          // Right
                                            dash_dx <= DASH_UPDATE;
                                            dash_dy <= 0;
                                            last_direction <= 5;
                                        end else if (btnD) begin          // Down
                                            dash_dx <= 0;
                                            dash_dy <= DASH_UPDATE;
                                            last_direction <= 3;
                                        end else if (btnL) begin          // Left
                                            dash_dx <= -DASH_UPDATE;
                                            dash_dy <= 0;
                                            last_direction <= 1;
                                        end else begin
                                            // Default to facing direction.
                                            if (facing == 0) begin
                                                dash_dx <= DASH_UPDATE; 
                                                dash_dy <= 0;
                                            end else begin
                                                dash_dx <= -DASH_UPDATE; 
                                                dash_dy <= 0;
                                            end
                                        end
                                        dashing <= 1;
                                        dash_counter <= DASH_DURATION;
                                        dash_ready <= 0;
                                    end
                                end
                            end
                        end else begin
                            player_x <= player_x;
                            y_pos_fp <= y_pos_fp;
                            player_y <= player_y;
                        end
                    end
                end

                SPRITE_EXPLODE: begin
                    if (explosion_timer < EXPLOSION_FRAME_DURATION - 1) begin
                        explosion_timer <= explosion_timer + 1;
                    end else begin
                        explosion_timer <= 0;
                        if (explosion_frame < MAX_EXPLOSION_FRAME - 1)
                            explosion_frame <= explosion_frame + 1;
                        else begin
                            case (lvl)
                                0: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                1: begin player_x <= 3; y_pos_fp <= (52 << 4); vy <= 0; player_y <= 8'd52; end
                                2: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                3: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                                default: begin player_x <= 3; y_pos_fp <= (56 << 4); vy <= 0; player_y <= 8'd56; end
                            endcase
                            sprite_state <= SPRITE_BLINK;
                            blink_timer <= 0;
                            blink_visible <= 1;
                            blink_for_transition <= 0;
                        end
                    end
                end

                SPRITE_BLINK: begin
                    blink_timer <= blink_timer + 1;
                    if (blink_timer % 20 == 0)
                        blink_visible <= ~blink_visible;
                    if ((blink_for_transition && blink_timer >= TRANSITION_BLINK_DURATION) ||
                        (!blink_for_transition && blink_timer >= BLINK_DURATION)) begin
                        sprite_state <= SPRITE_NORMAL;
                        blink_timer <= 0;
                        blink_visible <= 1;
                        blink_for_transition <= 0;
                    end
                end
            endcase
        end

        prev_lvl <= lvl;
        prev_game_active <= game_active;
        freeze_sprite_prev <= freeze_sprite;
    end

    //---------------------------------------------------
    // Sprite Overlay for the Player with Explosion Effect
    //---------------------------------------------------
    wire in_hitbox = game_active &&
        (x_coord >= player_x - 3) && (x_coord <= player_x + 3) &&
        (y_coord >= player_y - 3) && (y_coord <= player_y + 3);
    wire [2:0] sprite_local_x = x_coord - (player_x - 3);
    wire [2:0] sprite_local_y = y_coord - (player_y - 3);
    wire [2:0] effective_sprite_x = (facing == 0) ? (6 - sprite_local_x) : sprite_local_x;
    wire [5:0] sprite_addr;
    assign sprite_addr = sprite_local_y * 7 + effective_sprite_x;
    
    wire [15:0] sprite_pixel;
    sprite_rom #(.MEMFILE("chibi.mem")) spriteROM (
         .clk(clk6p25),
         .addr(sprite_addr),
         .data(sprite_pixel)
    );
    
    wire [7:0] pr_val;
    assign pr_val = (x_coord * 8'd17) + (y_coord * 8'd13) + explosion_frame;
    wire [15:0] explosion_color;
    assign explosion_color = (pr_val[0]) ? 16'hFFFF : 16'hF800;

    reg explosion_active;
    integer i, j;
    integer dx, dy;
    always @(*) begin
        explosion_active = 1'b0;
        if (sprite_state == SPRITE_EXPLODE) begin
            for (i = 0; i < 7; i = i + 1) begin
                for (j = 0; j < 7; j = j + 1) begin
                    dx = i - 3;
                    dy = j - 3;
                    if ((dx*dx + dy*dy) <= 9) begin
                        if ((x_coord == player_x + (dx * (1 + explosion_frame))) &&
                            (y_coord == player_y + (dy * (1 + explosion_frame))))
                            explosion_active = 1'b1;
                    end
                end
            end
        end
    end

    wire [15:0] final_sprite_out = freeze_sprite ? 16'h0000 : (
         (sprite_state == SPRITE_NORMAL) ? sprite_pixel :
         (sprite_state == SPRITE_BLINK)  ? (blink_visible ? sprite_pixel : 16'h0000) :
         (sprite_state == SPRITE_EXPLODE)? (explosion_active ? explosion_color : 16'h0000) :
                                          16'h0000
    );
    
    wire [15:0] final_pixel;
    assign final_pixel = ((sprite_state == SPRITE_NORMAL) || (sprite_state == SPRITE_BLINK)) ?
                           (in_hitbox ? ((final_sprite_out == 16'h0000) ? background_with_rain : final_sprite_out)
                                      : background_with_rain)
                         : ((explosion_active) ? explosion_color : background_with_rain);

    //---------------------------------------------------
    // OLED Display Controller Instantiation
    //---------------------------------------------------
    Oled_Display oled (
         .clk(clk6p25), 
         .reset(0), 
         .frame_begin(fb), 
         .sending_pixels(sendpixel),
         .sample_pixel(samplepixel), 
         .pixel_index(pixel_index),
         .pixel_data(final_pixel),
         .cs(JB[0]), 
         .sdin(JB[1]),
         .sclk(JB[3]), 
         .d_cn(JB[4]), 
         .resn(JB[5]), 
         .vccen(JB[6]), 
         .pmoden(JB[7])
    );

    //---------------------------------------------------
    // Collision and Level Logic Functions
    //---------------------------------------------------
    // input: x & y coordinates and level number
    // returns obstruction status in all 8 directions
    // from MSB to LSB: up upright right downright down downleft left upleft
    function [7:0] is_obstructed; 
        input [7:0] x,y;
        input [1:0] lvl;
        reg up, upright, right, downright, down, downleft, left, upleft;
        begin case (lvl)
            0: begin
                if (x <= 3) left = 1; // left boundary
                if (y <= 3) up = 1; // top of map
                if (x >= 92 && y <= 51) right = 1; // right boundary
                if (y >= 56 && y <= 62 && x >= 3 && x <= 21) down = 1; // floor platform 1
                if (y >= 56 && y <= 62 && (x == 22 || x == 68)) downleft = 1;
                if (y >= 56 && y <= 62 && x >= 28 && x <= 67) down = 1; // floor platform 2
                if (y >= 56 && y <= 62 && x >= 74 && x <= 92) down = 1; // floor platform 3
                if (y >= 56 && y <= 62 && (x == 27 || x == 73)) downright = 1;
            end
            1: begin
                if (y >= 62) down = 1;
                if (x == 11 && y == 51) upleft = 1;
                if (y >= 41 && y <= 51 && x >= 0 && x <= 10) up = 1; // ceiling above spawn 1
                if (x <= 3) left = 1; // wall 2
                if (y >= 52 && y <= 60 && x <= 20) down = 1; // floor 3
                if (x == 20 && y == 36) downright = 1;
                if (x >= 20 && x <= 28 && y >= 37 && y <= 52) right = 1; // wall right 4
                if (y >= 36 && y <= 46 && x >= 21 && x <= 34) down = 1; // floor 5
                if (x == 35 && y == 36) downleft = 1;
                if (x <= 35 && x >= 27 && y >= 37) left = 1; // left spike wall 6
                if (y >= 52 && y <= 62 && x >= 35 && x <= 52) down = 1; // spike floor 7
                if (x == 52 && y == 36) downright = 1;
                if (x >= 52 && x <= 62 && y >= 37) right = 1; // right spike wall 8
                if (y >= 36 && y <= 46 && x >= 53 && x <= 74) down = 1; // floor 9
                if (x == 75 && y == 36) downleft = 1;
                if (x <= 75 && x >= 65 && y >= 37 && y <= 52) left = 1; // left wall 10
                if (y >= 52 && y <= 62 && x >= 75) down = 1; // floor 11
                if (y <= 51 && y >= 41 && x >= 85) up = 1; // celing 12
                if (x == 84 && y == 51) upright = 1;
                if (x >= 84 && x <= 94 && y >= 11 && y <= 50) right = 1; // wall 13
                if (y == 11) up = 1; // ceiling 14
                if (x <= 11 && x >= 0 && y >= 11 && y <= 50) left = 1; // left wall 15
            end
            2: begin
                if (y >= 45 && y <= 55 && x >= 0 && x <= 6) up = 1; // spawn ceiling 1
                if (x <= 3) left = 1; // spawn left space 2
                if (y >= 56 && y <= 62 && x >= 3 && x <= 18) down = 1; // spawn floor 3
                if (x <= 19 && y >= 57 && y <= 60) left = 1; // spike left wall 4
                if (y >= 61 && x >= 19 && x <= 24) down = 1; // spike floor 5
                if (x >= 24 && x <= 34 && y >= 53 && y <= 60) right = 1;// spike right wall 6
                if (x == 24 && y == 52) downright = 1;
                if (y >= 52 && y <= 62 && x >= 25 && x <= 38) down = 1; // floor 7
                if (x == 39 && y == 52) downleft = 1;
                if (x == 44 && y == 36) downright = 1;
                if (x >= 44 && x <= 52 && y >= 37 && y <= 52) right = 1; // right spike wall 8 
                if (y >= 36 && y <= 46 && x >= 45 && x <= 58) down = 1; // floor 9
                if (x == 59 && y == 36) downleft = 1;
                if (x >= 53 && x <= 59 && y >= 37 && y <= 48) left = 1; // left spike wall 10
                if (x >= 59 && x <= 66 && y == 48) down = 1; // spike floor 11
                if (x >= 53 && x <= 67 && y >= 49) left = 1; // left void wall 12
                if (x == 67 && y == 48) downleft = 0;
                if (x >= 88 && y >= 55) right = 1; // right void wall 13 
                if (x == 84 && y == 54) upright = 1;
                if (x >= 85 && x <= 88 && y == 55) up = 1; // ceil 14
                if (x >= 84 && y >= 51 && y <= 54) right = 1; // right wall 15
                if (x == 80 && y == 51) upright = 1;
                if (x >= 81 && x <= 84 && y == 51) up = 1; // ceil 16
                if (x >= 80 && y >= 47 && y <= 50) right = 1; // right wall 17
                if (x == 76 && y == 47) upright = 1;
                if (x >= 77 && x <= 80 && y == 47) up = 1; // ceil 18
                if (x >= 76 && y >= 39 && y <= 46) right = 1; // right wall 19
                if (x >= 73 && x <= 76 && y == 39) up = 1; // ceil 20
                if (x == 72 && y == 39) upright = 1;
                if (x >= 72 && y >= 25 && y <= 38) right = 1; // right wall 21
                if (y == 72 && y == 25) downright = 1;
                if (x >= 73 && x <= 84 && y >= 24 && y <= 34) down = 1; // floor 22
                if (x >= 84 && y >= 23 && y <= 24) right = 1; // right wall 23
                if (x >= 81 && x <= 84 && y >= 19 && y <= 23) up = 1; // right ceil 24
                if (x == 80 && y == 23) upright = 1;
                if (x == 80 && y >= 14 && y <= 22) right = 1; // right wall 25
                if (x == 80 && y == 12) downright = 1;
                if (x >= 81 && x <= 84 && y >= 12 && y <= 16) down = 1; // floor 26
                if (x >= 84 && y >= 5 && y <= 12) right = 1; // right wall 27
                if (x == 84 && y == 4) downright = 1;
                if (x >= 85 && x <= 88 && y >= 4 && y <= 14) down = 1; // floor 28
                if (x >= 88 && y <= 5) right = 1; // right wall 29
                if (x <= 79 && y <= 7) left = 1; // left wall 30
                if (x == 79 && y == 7) upleft = 1;
                if (x >= 7 && x <= 78 && y <= 7) up = 1; // ceil 31
                if (x <= 7 && y >= 7 && y <= 54) left = 1; // left wall 32
                if (x == 7 && y == 55) upleft = 1;
            end
            3: begin
                if (x <= 3) left = 1; // left border 1
                if (y >= 56 && y <= 62 && x >= 3 && x <= 36) down = 1; // floor 2
                if (x >= 36 && x <= 43 && y >= 21 && y <= 49) right = 1; // rightwall 3
                if (x >= 36 && x <= 63 && y >= 50 && y <= 60) right = 1; // rightwall 3
                if (x == 36 && y == 20) downright = 1;
                if (y >= 20 && y <= 30 && x >= 37 && x <= 50) down = 1; // spikefloor 4
                if (x == 51 && y == 20) downleft = 1;
                if (x <= 51 && x >= 44 && y >= 21 && y <= 48) left = 1; // left wall 5
                if (y >= 48 && y <= 58 && x >= 51 && x <= 64) down = 1; // spike floor 6
                if (x <= 71 && x >= 49 && y >= 49) left = 1; // left void wall 7
                if (y <= 51 && x >= 89) up = 1; // void ceiling 8
                if (x == 88 && y == 51) upright = 1;
                if (x >= 88 && y >= 42 && y <= 50) right = 1; // right wall 9
                if (y >= 35 && y <= 42 && x >= 73 && x <= 88) up = 1; // void ceiling 10
                if (x == 72 && y == 42) upright = 1;
                if (x >= 72 && y >= 28 && y <= 41) right = 1; // right wall 11
                if (x == 72 && y == 27) downright = 1; 
                if (y >= 27 && y <= 34 && x >= 73 && x <= 84) down = 1; // flower floor 12
                if (x >= 84 && y <= 27) right = 1; // exit right wall 13
                if (x >= 68 && x <= 75 && y <= 15) left = 1; // left exit wall 14
                if (y <= 16 && x >= 71 && x <= 74) up = 1; // ceiling 15
                if (x == 75 && y == 16) upleft = 1;
                if (x >= 67 && x <= 71 && y >= 16 && y <= 19) left = 1; // left ceiling wall 16
                if (x == 71 && y == 20) upleft = 1;
                if (y <= 20 && x >= 61 && x <= 70) up = 1; // small ceiling block 17
                if (x == 60 && y == 20) upright = 1;
                if (x >= 60 && x <= 66 && y >= 7 && y <= 19) right = 1; // right ceiling wall 18
                if (y <= 7 && x >= 26 && x <= 60) up = 1; // big ceiling 19
                if (x <= 26 && y >= 7 && y <= 14) left = 1; // left celing wall 20
                if (x == 26 && y == 15) upleft = 1;
                if (y <= 15 && x >= 14 && x <= 25) up = 1; // left top ceiling 21
                if (x <= 14 && y >= 15 && y <= 20) left = 1; // left berry bush wall 22
                if (y >= 20 && y <= 30 && x >= 14 && x <= 30) down = 1; // higher floor 23
                if (x == 31 && y == 20) downleft = 1;
                if (x <= 31 && y >= 21 && y <= 54) left = 1; // long left wall 24
                if (x == 31 && y == 55) upleft = 1;
                if (y >= 30 && y <= 55 && x >= 14 && x <= 30) up = 1; // 3rd spawn ceiling 25
                if (x >= 13 && x <= 20 && y >= 51 && y <= 54) right = 1; // 3rd spawn celing 26
                if (x == 13 && y == 55) upright = 1; 
                if (y >= 30 && y <= 51 && x >= 6 && x <= 13) up = 1; // 2nd spawn ceiling 27
                if (y == 51 && x == 5) upright = 1; 
                if (x >= 5 && x <= 20 && y >= 47 && y <= 50) right = 1; // 2nd spawn celing 28
                if (y <= 47 && x >= 3 && x <= 5) up = 1; // 1st spawn ceiling 29
            end
        endcase
            is_obstructed = (up << 7) | (upright << 6) | (right << 5) | (downright << 4) | 
                            (down << 3) | (downleft << 2) | (left << 1) | upleft;
        end
    endfunction
    
    function is_dead;
        input [7:0] x, y;
        input [1:0] lvl;
        begin 
            case (lvl)
                0: is_dead = ((y >= 57 && x >= 22 && x <= 27) ||
                              (y >= 57 && x >= 67 && x <= 73));
                1: is_dead = ((x >= 35 && x <= 53) && (y >= 49 && y <= 63));
                2: is_dead = ((y >= 53 && y <= 63 && x >= 36 && x <= 47) ||
                              (y >= 45 && y <= 48 && x >= 59 && x <= 64) ||
                              (y == 64 && x >= 67 && x <= 88) ||
                              (y >= 57 && x >= 19 && x <= 24) ||
                              (y > 64));
                3: is_dead = ((y >= 45 && y <= 48 && x >= 51 && x <= 63) ||
                              (y >= 17 && y <= 20 && x >= 38 && x <= 48) ||
                              (y >= 64 && x >= 72) ||
                              (y >= 51 && x >= 96));
                default: is_dead = 0;
            endcase   
        end
    endfunction
    
    function is_lvldone;
        input [7:0] x, y;
        input [1:0] lvl;
        begin 
            case (lvl)
                0: is_lvldone = (x >= 96);
                1: is_lvldone = (x >= 96 && y >= 48 && y <= 55);
                2: is_lvldone = (y <= 3 && x >= 76);
                3: is_lvldone = (y <= 3 && x >= 72);
            endcase
        end
    endfunction

endmodule

