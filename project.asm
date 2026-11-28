; EL2003 - COMPUTER ORGANIZATION AND ASSEMBLY LANGUAGE
; SEMESTER PROJECT: BABY PEACH ENGINE (16-Bit Real Mode, VGA Mode 13h)
; Tools: NASM + DOSBox | Executable: MARIO.COM (Single Segment, ORG 100h)
; BUILD:    nasm MARIO.asm -f bin -O0 -o MARIO.COM   (no -O2 needed)
; CONTROLS: Left/Right = move, Left Shift = run, Space = jump, P = pause,
;           Enter = select, Up/Down = menu, Esc = back/exit
; DEBUG KEYS (list in README): T = clock to 5 s, C = coins to 99
[org 0x0100]
cpu 386
   
    jmp near main_entry

; MODULE 1: CONSTANTS & DATA DEFINITIONS (Appendix A)

SCREEN_W        EQU 320
SCREEN_H        EQU 200
MAP_COLS        EQU 60
MAP_ROWS        EQU 12
MAP_SIZE        EQU 720         ; 60 * 12 bytes
MAX_CAMERA_X    EQU 640         ; 960 - 320
WORLD_MAX_X     EQU 944         ; 960 - 16
MAX_ENEMIES     EQU 8

; --- VGA Palette Color Indices ---
COL_TRANS       EQU 0
COL_BLACK       EQU 0
COL_BLUE        EQU 1
COL_GREEN       EQU 2
COL_RED         EQU 4
COL_BROWN       EQU 6
COL_GRAY        EQU 8
COL_LGREEN      EQU 10
COL_YELLOW      EQU 14
COL_WHITE       EQU 15
COL_ORANGE      EQU 42
COL_SKIN        EQU 43
COL_SKY         EQU 53

; --- Custom Theme Palette Indices (Programmed via VGA DAC) ---
COL_STAR_GOLD   EQU 200         ; 0xFFF9A825 (Star Coins & Crown)
COL_ROSE        EQU 201         ; #FC94AF (Rose / Dark Pink)
COL_LEMONADE    EQU 202         ; #FCBACB (Lemonade / Light Pink Dress)
COL_LILAC       EQU 203         ; #C8A2C8 (Lilac)
COL_PERIWINKLE  EQU 204         ; #E9CFEC (Periwinkle)
COL_HUD_BG      EQU 205         ; 0xFF0D47A1 (Dark Blue Scoreboard)

; HUD bar: dark blue scoreboard. Ground body: brown.
; (Use COL_BLACK here for a black HUD, COL_GREEN for a green ground.)
COL_HUD         EQU COL_HUD_BG
COL_DIRT        EQU COL_BROWN

; --- Tile Codes (Appendix A.2) ---
TILE_SKY        EQU 0
TILE_GROUND     EQU 1
TILE_BRICK      EQU 2
TILE_Q_COIN     EQU 3
TILE_Q_MUSH     EQU 4
TILE_EMPTY      EQU 5
TILE_PIPE_TL    EQU 6
TILE_PIPE_TR    EQU 7
TILE_PIPE_BL    EQU 8
TILE_PIPE_BR    EQU 9
TILE_STAIR      EQU 10
TILE_COIN       EQU 11
TILE_FLAG       EQU 12

; --- Keyboard Scan Codes (Appendix A.3) ---
KEY_ESC         EQU 0x01
KEY_T_DEBUG     EQU 0x14        ; Debug key 'T': sets clock to 5s
KEY_P           EQU 0x19
KEY_ENTER       EQU 0x1C
KEY_LSHIFT      EQU 0x2A
KEY_C_DEBUG     EQU 0x2E        ; Debug key 'C': sets coins to 99
KEY_SPACE       EQU 0x39
KEY_UP          EQU 0x48
KEY_LEFT        EQU 0x4B
KEY_RIGHT       EQU 0x4D
KEY_DOWN        EQU 0x50

; --- 8.8 Fixed-Point Physics Constants (Boosted High-Speed Running) ---
WALK_ACCEL      EQU 0x0060      ; 0.375 px/frame (smooth acceleration)
FRICTION        EQU 0x0030      ; 0.1875 px/frame (stopping)
MAX_WALK        EQU 0x0280      ; 2.5 px/frame (walk speed)
MAX_RUN         EQU 0x0400      ; 4.0 px/frame (run speed with Left Shift)
GRAVITY         EQU 0x0040      ; 0.25 px/frame
JUMP_VEL        EQU 0xFA80      ; -5.5 px/frame
JUMP_CUTOFF     EQU 0xFE00      ; -2.0 px/frame
MAX_FALL        EQU 0x0400      ; 4.0 px/frame
STOMP_BOUNCE    EQU 0xFD00      ; -3.0 px/frame
GOOMBA_SPEED    EQU 0x00A0      ; 0.625 px/frame
KOOPA_SPEED     EQU 0x00E0      ; 0.875 px/frame
SHELL_SPEED     EQU 0x0380      ; 3.5 px/frame
MUSH_SPEED      EQU 0x0140      ; 1.25 px/frame

; --- Game States (Section 5.12) ---
ST_TITLE        EQU 0
ST_PLAYING      EQU 1
ST_PAUSED       EQU 2
ST_DYING        EQU 3
ST_LIFE_LOST    EQU 4
ST_WIN_SEQ      EQU 5
ST_LEVEL_COMP   EQU 6
ST_GAME_OVER    EQU 7
ST_EXIT         EQU 8

; --- System & Interrupt Variables ---
buf_seg         dw 0
old_kb_isr      dd 0
old_tm_isr      dd 0

; 128-byte key_state table (8 rows x 16 bytes)
key_state:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; 128-byte key_edge table (8 rows x 16 bytes)
key_edge:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

tick_count      dw 0
tick_delta      dw 1
last_tick       dw 0
sec_ticks       dw 0
frame_counter   dw 0

; --- State Machine Variables ---
game_state      dw ST_TITLE
prev_state      dw 0xFFFF
menu_sel        db 0
state_timer     dw 0

; --- Hero Data (Baby Peach - Modules 9, 13) ---
mario_x         dw 32           ; Integer world X (0..960)
mario_x_sub     db 0            ; .8 fixed-point fractional X
mario_y         dw 128          ; Integer world Y (top of sprite)
mario_y_sub     db 0            ; .8 fixed-point fractional Y
mario_prev_y    dw 128
mario_vx        dw 0            ; 8.8 signed fixed-point velocity X
mario_vy        dw 0            ; 8.8 signed fixed-point velocity Y
mario_dir       db 0            ; 0 = Right, 1 = Left
mario_on_ground db 0
mario_hp        db 1            ; 1 = Small (16x16), 2 = Super (16x32)
mario_invuln    dw 0
stomp_chain     dw 0
camera_x        dw 0

; --- Score, Coins, Lives, Clock (Module 13) ---
score_low       dw 0
score_high      dw 0
time_bonus_val  dw 0
coins           db 0
lives           db 3
game_clock      dw 300

; --- Mushroom Entity ---
mush_active     db 0
mush_x          dw 0
mush_y          dw 0
mush_vy         dw 0
mush_y_sub      db 0
mush_dir        db 0            ; 0 = Right, 1 = Left

; --- Enemy Table (8 records x 12 bytes = 96 bytes) ---
enemy_table:
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0

; Spawn Table: type, col, row
enemy_spawns:
    db 1, 13, 9
    db 1, 19, 9
    db 1, 26, 9
    db 1, 33, 9
    db 2, 39, 9
    db 2, 46, 9
    db 1, 48, 9
    db 0, 0,  0

stomp_table     dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000

; --- UI Text Strings ---
str_title1      db 'BABY PEACH', 0
str_title2      db 'E N G I N E', 0
str_start       db 'START GAME', 0
str_exit        db 'EXIT', 0
str_cursor      db '>', 0
str_group       db 'COAL Project | 25F 0729', 0
str_hud_top     db 'SCORE   COINS WORLD TIME LIVES HEALTH', 0
str_world       db '1-1', 0
str_paused      db 'P A U S E D', 0
str_resume      db 'Press P to resume', 0
str_lifelost1   db 'WORLD 1-1', 0
str_lifelost2   db 'LIVES LEFT', 0
str_gameover1   db 'G A M E   O V E R', 0
str_gameover2   db 'Final Score:', 0
str_gameover3   db 'Press ENTER for the title', 0
str_lvlcomp1    db 'LEVEL COMPLETE!', 0
str_lvlcomp2    db 'SCORE          ', 0
str_lvlcomp3    db 'COINS          x ', 0
str_lvlcomp4    db 'TIME BONUS     + ', 0
str_lvlcomp5    db 'FINAL SCORE    ', 0
str_lvlcomp6    db 'Press ENTER to continue', 0
str_lvlcomp7    db 'TIME LEFT         ', 0

; --- Level Map (60 columns x 12 rows = 720 bytes, Section 5.15) ---
original_map:
; Row 0: HUD strip (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
; Row 1: Sky (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
; Row 2: Flag top at col 56 (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,12,0,0,0
; Row 3: High "?" block at col 16, Flag at col 56 (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,3,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,12,0,0,0
; Row 4: Flag at col 56 (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,12,0,0,0
; Row 5: Coins over pits, Stairs top (col 53), Flag (col 56) (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,11,11,11,11,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,11,11,11,0,0,0,0,0,0, 0,0,0,10,0,0,12,0,0,0
; Row 6: "?" blocks (2 mushroom, 3 coin), brick groups, stairs, flag (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 4,0,0,0,2,3,2,4,2,0
    db 0,0,0,0,0,0,0,0,0,0, 2,3,2,2,2,0,0,0,0,0
    db 0,0,0,0,0,2,3,2,2,2, 0,0,10,10,0,0,12,0,0,0
; Row 7: 3-tile pipe top (cols 36-37), stairs, flag (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,6,7,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,10,10,10,0,0,12,0,0,0
; Row 8: 2-tile pipe top (28-29), coins (31-33), 3-tile pipe body (36-37), stairs, flag (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,6,7, 0,11,11,11,0,0,8,9,0,0
    db 0,0,0,0,0,0,0,0,0,0, 10,10,10,10,0,0,12,0,0,0
; Row 9: Pipe bodies, stairs, flag base (60 bytes)
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,8,9, 0,0,0,0,0,0,8,9,0,0
    db 0,0,0,0,0,0,0,0,0,0, 10,10,10,10,0,0,10,0,0,0
; Row 10: Ground with 2 pits (cols 22-23 and cols 41-43) (60 bytes)
    db 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1
    db 1,1,0,0,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1
; Row 11: Ground bottom row (60 bytes)
    db 1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1
    db 1,1,0,0,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1
    db 1,0,0,0,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1

; Working Map Buffer (60 columns x 12 rows = 720 bytes)
working_map:
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0


; MODULE 4: SPRITE BITMAPS (16x16 = 256 bytes each)

%macro PEACH_HEAD 0
    db 0,0,0,0,200,0,200,200,0,200,0,0,0,0,0,0
    db 0,0,0,0,200,200,4,4,200,200,0,0,0,0,0,0
    db 0,0,0,1,200,200,4,4,200,1,0,0,0,0,0,0
    db 0,0,0,14,14,14,14,14,14,14,14,0,0,0,0,0
    db 0,0,14,14,14,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,14,14,43,43,14,14,43,43,14,14,0,0,0,0
    db 0,0,0,14,43,1,15,43,43,1,15,43,0,0,0,0
    db 0,0,0,43,43,1,0,43,43,1,0,43,0,0,0,0
    db 0,0,0,0,43,43,43,43,43,201,201,201,0,0,0,0
    db 0,0,0,0,0,43,43,43,43,201,201,201,0,0,0,0
%endmacro
%macro PEACH_DRESS 0
    db 0,0,0,201,202,202,202,202,1,202,0,0,0,0,0,0
    db 0,0,43,201,202,202,202,202,1,202,43,0,0,0,0,0
    db 0,0,0,201,202,202,202,202,202,202,0,0,0,0,0,0
    db 0,0,0,201,201,201,201,201,201,201,0,0,0,0,0,0
%endmacro
; Baby Peach (16x16, facing right): 200=gold crown, 4=red jewel/shoes,
; 1=blue, 14=blonde hair, 43=skin, 201=rose, 202=pink dress, 15=white
spr_baby_peach:                     ; standing pose
    PEACH_HEAD
    PEACH_DRESS
    db 0,0,0,0,15,15,0,0,15,15,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,0,4,4,4,0,0,0,0,0
spr_peach_run1:                     ; running pose, legs apart
    PEACH_HEAD
    PEACH_DRESS
    db 0,0,0,15,15,0,0,0,0,15,15,0,0,0,0,0
    db 0,0,4,4,4,0,0,0,0,4,4,4,0,0,0,0
spr_peach_run2:                     ; running pose, legs together
    PEACH_HEAD
    PEACH_DRESS
    db 0,0,0,0,0,15,15,15,15,0,0,0,0,0,0,0
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
spr_peach_jump:                     ; jumping pose, arms up, legs spread
    PEACH_HEAD
    db 0,0,43,201,202,202,202,202,1,202,43,0,0,0,0,0
    db 0,0,0,201,202,202,202,202,1,202,0,0,0,0,0,0
    db 0,0,0,201,202,202,202,202,202,202,0,0,0,0,0,0
    db 0,0,0,201,201,201,201,201,201,201,0,0,0,0,0,0
    db 0,0,15,15,0,0,0,0,0,0,15,15,0,0,0,0
    db 0,4,4,4,0,0,0,0,0,0,4,4,4,0,0,0

spr_goomba:
    db 0,0,0,0,0,0,6,6,6,6,0,0,0,0,0,0
    db 0,0,0,0,6,6,6,6,6,6,6,6,0,0,0,0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,6,6,6,6,6,6,6,6,6,6,6,0,0
    db 0,6,6,15,15,6,6,6,6,6,6,15,15,6,6,0
    db 0,6,6,15,0,6,6,6,6,6,6,0,15,6,6,0
    db 6,6,6,15,0,6,6,6,6,6,6,0,15,6,6,6
    db 6,6,6,15,15,6,6,6,6,6,6,15,15,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 0,6,6,6,6,43,43,43,43,43,43,6,6,6,6,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,0,43,43,43,43,43,43,43,43,0,0,0,0
    db 0,0,0,8,8,8,0,0,0,0,8,8,8,0,0,0
    db 0,0,8,8,8,8,0,0,0,0,8,8,8,8,0,0
    db 0,0,8,8,8,8,0,0,0,0,8,8,8,8,0,0

spr_goomba_flat:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,15,0,6,6,6,6,6,6,0,15,6,0,0
    db 0,6,6,6,6,6,6,6,6,6,6,6,6,6,6,0
    db 0,0,6,6,43,43,43,43,43,43,43,43,6,6,0,0
    db 0,0,0,8,8,8,0,0,0,0,8,8,8,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_koopa:
    db 0,0,0,0,0,14,14,14,14,0,0,0,0,0,0,0
    db 0,0,0,0,14,14,15,0,14,14,0,0,0,0,0,0
    db 0,0,0,0,14,14,15,0,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,14,14,14,14,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,14,14,0,0,0,0,0,0,0,0
    db 0,0,0,0,2,2,2,2,2,2,2,0,0,0,0,0
    db 0,0,0,2,10,2,2,10,2,2,10,2,0,0,0,0
    db 0,0,2,2,2,10,10,2,2,10,10,2,2,0,0,0
    db 0,0,2,10,2,2,2,10,10,2,2,10,2,0,0,0
    db 0,0,2,2,2,2,2,2,2,2,2,2,2,0,0,0
    db 0,0,0,15,15,15,15,15,15,15,15,15,0,0,0,0
    db 0,0,0,0,14,14,0,0,0,14,14,0,0,0,0,0
    db 0,0,0,14,14,14,0,0,0,14,14,14,0,0,0,0
    db 0,0,0,14,14,0,0,0,0,0,14,14,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_shell:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,2,2,2,2,2,2,2,2,0,0,0,0
    db 0,0,0,2,10,2,2,10,10,2,2,10,2,0,0,0
    db 0,0,2,2,2,10,10,2,2,10,10,2,2,2,0,0
    db 0,0,2,10,2,2,2,10,10,2,2,2,10,2,0,0
    db 0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0
    db 0,0,0,15,15,15,15,15,15,15,15,15,15,0,0,0
    db 0,0,0,0,15,0,15,15,15,15,0,15,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

spr_mushroom:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,4,4,4,15,15,15,15,4,4,4,0,0,0
    db 0,0,4,4,4,15,15,15,15,15,15,4,4,4,0,0
    db 0,4,4,4,4,15,15,15,15,15,15,4,4,4,4,0
    db 0,4,15,15,4,4,15,15,15,15,4,4,15,15,4,0
    db 4,15,15,15,4,4,4,4,4,4,4,4,15,15,15,4
    db 4,15,15,15,4,4,4,4,4,4,4,4,15,15,15,4
    db 4,4,15,4,4,4,4,4,4,4,4,4,4,15,4,4
    db 0,4,4,4,4,4,4,4,4,4,4,4,4,4,4,0
    db 0,0,0,43,43,43,43,43,43,43,43,43,43,0,0,0
    db 0,0,43,43,43,0,43,43,43,43,0,43,43,43,0,0
    db 0,0,43,43,43,0,43,43,43,43,0,43,43,43,0,0
    db 0,0,43,43,43,43,43,43,43,43,43,43,43,43,0,0
    db 0,0,0,43,43,43,43,43,43,43,43,43,43,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Star-shaped Coin Sprite (16x16, Color Index 200 = 0xFFF9A825)
spr_star:
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,200,200,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,200,200,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,200,200,200,200,0,0,0,0,0,0
    db 0,0,0,0,0,0,200,200,200,200,0,0,0,0,0,0
    db 0,200,200,200,200,200,200,200,200,200,200,200,200,200,200,0
    db 0,0,200,200,200,200,200,200,200,200,200,200,200,200,0,0
    db 0,0,0,200,200,200,200,200,200,200,200,200,200,0,0,0
    db 0,0,0,0,200,200,200,200,200,200,200,200,0,0,0,0
    db 0,0,0,0,200,200,200,200,200,200,200,200,0,0,0,0
    db 0,0,0,200,200,200,200,0,0,200,200,200,200,0,0,0
    db 0,0,0,200,200,200,0,0,0,0,200,200,200,0,0,0
    db 0,0,200,200,200,0,0,0,0,0,0,200,200,200,0,0
    db 0,0,200,200,0,0,0,0,0,0,0,0,200,200,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; =============================================================================
; ENTRY POINT & MAIN STATE MACHINE (Modules 1, 14, 15)
; =============================================================================
main_entry:
    mov ax, cs
    add ax, 0x1000                  ; Reserve next 64KB segment for Frame Buffer
    mov [buf_seg], ax

    call hook_interrupts
    call init_video_mode13h
    call reset_new_game
    mov word [game_state], ST_TITLE

state_machine_loop:
.wait_tick:
    mov ax, [tick_count]
    cmp ax, [last_tick]
    jne $+5
    jmp near .wait_tick
    mov bx, ax
    sub bx, [last_tick]             ; ticks elapsed since the previous frame
    mov [tick_delta], bx
    mov [last_tick], ax
    inc word [frame_counter]

    mov bx, [game_state]
    cmp bx, [prev_state]
    jne $+5
    jmp near .dispatch
    mov [prev_state], bx            ; state changed: throw away old key presses
    push cs
    pop es
    mov di, key_edge
    mov cx, 128
    xor al, al
    cld
    rep stosb
.dispatch:
    shl bx, 1
    jmp [state_jump_table + bx]

state_jump_table:
    dw state_title_fn
    dw state_playing_fn
    dw state_paused_fn
    dw state_dying_fn
    dw state_life_lost_fn
    dw state_win_seq_fn
    dw state_level_comp_fn
    dw state_game_over_fn
    dw state_exit_fn


; STATE 0: TITLE SCREEN
; -----------------------------------------------------------------------------
state_title_fn:
    cmp byte [key_state + KEY_UP], 1
    je $+5
    jmp near .chk_down
    mov byte [menu_sel], 0
.chk_down:
    cmp byte [key_state + KEY_DOWN], 1
    je $+5
    jmp near .chk_esc
    mov byte [menu_sel], 1
.chk_esc:
    cmp byte [key_edge + KEY_ESC], 1
    je $+5
    jmp near .chk_enter
    mov byte [key_edge + KEY_ESC], 0
    mov word [game_state], ST_EXIT
    jmp near state_machine_loop
.chk_enter:
    cmp byte [key_edge + KEY_ENTER], 1
    je $+5
    jmp near .render
    mov byte [key_edge + KEY_ENTER], 0
    cmp byte [menu_sel], 0
    je $+5
    jmp near .do_exit
    call reset_new_game
    mov word [game_state], ST_PLAYING
    jmp near state_machine_loop
.do_exit:
    mov word [game_state], ST_EXIT
    jmp near state_machine_loop

.render:
    push word COL_SKY
    call clear_buffer

    push word 0
    push word 168
    push word 320
    push word 32
    push word COL_GREEN
    call fill_rect

    push word 0
    push word 168
    push word 320
    push word 4
    push word COL_LGREEN
    call fill_rect

    push word 90
    push word 85
    push word 140
    push word 55
    push word COL_BLACK
    call fill_rect

    push word 120
    push word 40
    push word COL_ROSE
    push word str_title1
    call draw_string

    push word 116
    push word 56
    push word COL_WHITE
    push word str_title2
    call draw_string

    push word 120
    push word 98
    push word COL_YELLOW
    push word str_start
    call draw_string

    push word 120
    push word 118
    push word COL_WHITE
    push word str_exit
    call draw_string

    mov ax, 98
    cmp byte [menu_sel], 1
    je $+5
    jmp near .draw_cur
    mov ax, 118
.draw_cur:
    push word 104
    push ax
    push word COL_YELLOW
    push word str_cursor
    call draw_string

    push word 48
    push word 152
    push word spr_baby_peach
    push word 0
    call draw_sprite

    push word 248
    push word 152
    push word spr_goomba
    push word 0
    call draw_sprite

    push word 64
    push word 180
    push word COL_WHITE
    push word str_group
    call draw_string

    call flip_buffer
    jmp near state_machine_loop


; STATE 1: PLAYING (Section 5.13 Frame Order)
; -----------------------------------------------------------------------------
state_playing_fn:
    cmp byte [key_edge + KEY_P], 1
    je $+5
    jmp near .chk_esc
    mov byte [key_edge + KEY_P], 0
    mov word [game_state], ST_PAUSED
    jmp near state_machine_loop
.chk_esc:
    cmp byte [key_edge + KEY_ESC], 1
    je $+5
    jmp near .chk_dbg_t
    mov byte [key_edge + KEY_ESC], 0
    mov word [game_state], ST_TITLE
    jmp near state_machine_loop
.chk_dbg_t:
    cmp byte [key_edge + KEY_T_DEBUG], 1
    je $+5
    jmp near .chk_dbg_c
    mov byte [key_edge + KEY_T_DEBUG], 0
    mov word [game_clock], 5
.chk_dbg_c:
    cmp byte [key_edge + KEY_C_DEBUG], 1
    je $+5
    jmp near .step3
    mov byte [key_edge + KEY_C_DEBUG], 0
    mov byte [coins], 99

.step3:
    call update_mario_physics
    call update_mushroom
    call update_enemies
    call check_entity_collisions

    cmp word [mario_invuln], 0
    jne $+5
    jmp near .clock_upd
    dec word [mario_invuln]
.clock_upd:
    mov ax, [tick_delta]            ; clock follows real timer ticks, not frames
    add [sec_ticks], ax
    cmp word [sec_ticks], 30        ; 30 ticks = 1 real second at 30 Hz
    jae $+5
    jmp near .step7
    sub word [sec_ticks], 30
    cmp word [game_clock], 0
    jne $+5
    jmp near .step7
    dec word [game_clock]

.step7:
    ; Check Flag Pole Win (Column 56 -> X >= 888)
    mov ax, [mario_x]
    cmp ax, 888
    jae $+5
    jmp near .chk_deaths
    call trigger_flag_win
    jmp near state_machine_loop

.chk_deaths:
    cmp byte [mario_hp], 0
    jne $+5
    jmp near .trigger_death
    cmp word [mario_y], 192
    jl $+5
    jmp near .trigger_pit_death
    cmp word [game_clock], 0
    jne $+5
    jmp near .trigger_death
    jmp near .step8

.trigger_pit_death:
    mov byte [mario_hp], 0
    mov word [mario_vy], 0
    mov word [state_timer], 45      ; ~1.5s at 30 FPS
    mov word [game_state], ST_DYING
    jmp near state_machine_loop

.trigger_death:
    mov byte [mario_hp], 0
    mov word [mario_vy], JUMP_VEL
    mov word [state_timer], 45      ; ~1.5s at 30 FPS
    mov word [game_state], ST_DYING
    jmp near state_machine_loop

.step8:
    call update_camera
    call render_gameplay_frame
    call flip_buffer
    jmp near state_machine_loop

; STATE 2: PAUSED
; -----------------------------------------------------------------------------
state_paused_fn:
    cmp byte [key_edge + KEY_P], 1
    je $+5
    jmp near .chk_esc
    mov byte [key_edge + KEY_P], 0
    mov word [game_state], ST_PLAYING
    jmp near state_machine_loop
.chk_esc:
    cmp byte [key_edge + KEY_ESC], 1
    je $+5
    jmp near .render
    mov byte [key_edge + KEY_ESC], 0
    mov word [game_state], ST_TITLE
    jmp near state_machine_loop
.render:
    call render_gameplay_frame
    push word 92
    push word 75
    push word 136
    push word 45
    push word COL_BLACK
    call fill_rect

    push word 116
    push word 85
    push word COL_YELLOW
    push word str_paused
    call draw_string

    push word 92
    push word 102
    push word COL_WHITE
    push word str_resume
    call draw_string

    call flip_buffer
    jmp near state_machine_loop

; STATE 3: DYING ANIMATION
; -----------------------------------------------------------------------------
state_dying_fn:
    mov ax, [mario_vy]
    add ax, GRAVITY
    mov [mario_vy], ax
    add [mario_y_sub], al
    mov al, ah
    cbw
    adc [mario_y], ax

    call render_gameplay_frame
    call flip_buffer

    dec word [state_timer]
    jz $+5
    jmp near .done
    dec byte [lives]
    cmp byte [lives], 0
    jne $+5
    jmp near .go_gameover
    mov word [state_timer], 60      ; ~2.0s at 30 FPS
    mov word [game_state], ST_LIFE_LOST
    jmp near state_machine_loop
.go_gameover:
    mov word [game_state], ST_GAME_OVER
.done:
    jmp near state_machine_loop

; STATE 4: LIFE LOST SCREEN
; -----------------------------------------------------------------------------
state_life_lost_fn:
    push word COL_BLACK
    call clear_buffer

    push word 124
    push word 60
    push word COL_WHITE
    push word str_lifelost1
    call draw_string

    push word 132
    push word 92
    push word spr_baby_peach
    push word 0
    call draw_sprite

    mov al, [lives]
    xor ah, ah
    push word 164
    push word 96
    push ax
    push word 2
    push word COL_WHITE
    call draw_number

    push word 120
    push word 130
    push word COL_YELLOW
    push word str_lifelost2
    call draw_string

    call flip_buffer

    dec word [state_timer]
    jz $+5
    jmp near .wait
    call reset_level_life
    mov word [game_state], ST_PLAYING
.wait:
    jmp near state_machine_loop

; STATE 5: WIN SEQUENCE
; -----------------------------------------------------------------------------
state_win_seq_fn:
    mov ax, 128                     ; slide ends with feet on the base block
    mov dx, 144                     ; ground level to walk on afterwards
    cmp byte [mario_hp], 2
    je $+5
    jmp near .chk_slide
    mov ax, 112
    mov dx, 128
.chk_slide:
    cmp [mario_y], ax
    jl $+5
    jmp near .walk_right
    add word [mario_y], 3           ; slide down the pole
    jmp near .render
.walk_right:
    cmp word [mario_x], 928
    jl $+5
    jmp near .render
    inc word [mario_x]
    cmp word [mario_x], 912         ; past the base block: drop to the ground
    jge $+5
    jmp near .render
    cmp [mario_y], dx
    jl $+5
    jmp near .render
    add word [mario_y], 2
.render:
    call render_gameplay_frame
    call flip_buffer
    dec word [state_timer]
    jz $+5
    jmp near .done

    mov ax, [game_clock]
    mov bx, 50
    mul bx
    mov [time_bonus_val], ax
    push ax
    call add_score
    mov word [game_state], ST_LEVEL_COMP
.done:
    jmp near state_machine_loop

; STATE 6: LEVEL COMPLETE SCREEN
; -----------------------------------------------------------------------------
state_level_comp_fn:
    cmp byte [key_edge + KEY_ENTER], 1
    je $+5
    jmp near .render
    mov byte [key_edge + KEY_ENTER], 0
    mov word [game_state], ST_TITLE
    jmp near state_machine_loop
.render:
    push word COL_BLACK
    call clear_buffer

    push word 100
    push word 28
    push word COL_YELLOW
    push word str_lvlcomp1
    call draw_string

    mov ax, [time_bonus_val]        ; show the score as it was before the bonus
    sub [score_low], ax
    sbb word [score_high], 0
    push word 64
    push word 56
    push word COL_WHITE
    push word str_lvlcomp2
    call draw_string
    push word 184
    push word 56
    call draw_score_6digits
    mov ax, [time_bonus_val]
    add [score_low], ax
    adc word [score_high], 0

    push word 64
    push word 76
    push word COL_WHITE
    push word str_lvlcomp3
    call draw_string
    mov al, [coins]
    xor ah, ah
    push word 200
    push word 76
    push ax
    push word 2
    push word COL_WHITE
    call draw_number

    push word 64
    push word 96
    push word COL_WHITE
    push word str_lvlcomp7
    call draw_string
    push word 200
    push word 96
    push word [game_clock]
    push word 3
    push word COL_WHITE
    call draw_number

    push word 64
    push word 116
    push word COL_WHITE
    push word str_lvlcomp4
    call draw_string
    push word 200
    push word 116
    push word [time_bonus_val]
    push word 5
    push word COL_WHITE
    call draw_number

    push word 64
    push word 136
    push word COL_YELLOW
    push word str_lvlcomp5
    call draw_string
    push word 184
    push word 136
    call draw_score_6digits

    push word 68
    push word 168
    push word COL_LGREEN
    push word str_lvlcomp6
    call draw_string

    call flip_buffer
    jmp near state_machine_loop


; STATE 7: GAME OVER SCREEN
; -----------------------------------------------------------------------------
state_game_over_fn:
    cmp byte [key_edge + KEY_ENTER], 1
    je $+5
    jmp near .render
    mov byte [key_edge + KEY_ENTER], 0
    mov word [game_state], ST_TITLE
    jmp near state_machine_loop
.render:
    push word COL_BLACK
    call clear_buffer

    push word 92
    push word 60
    push word COL_RED
    push word str_gameover1
    call draw_string

    push word 80
    push word 96
    push word COL_WHITE
    push word str_gameover2
    call draw_string

    push word 184
    push word 96
    call draw_score_6digits

    push word 60
    push word 140
    push word COL_LGREEN
    push word str_gameover3
    call draw_string

    call flip_buffer
    jmp near state_machine_loop

; STATE 8: EXIT TO DOS
; -----------------------------------------------------------------------------
state_exit_fn:
    call unhook_interrupts
    mov ax, 0x0003
    int 0x10
    mov ax, 0x4C00
    int 0x21


; MODULE 2 & 5: VIDEO MODE, CUSTOM VGA PALETTE, DOUBLE BUFFER & PIXEL PRIMITIVES


init_video_mode13h:
    push ax
    mov ax, 0x0013
    int 0x10
    call setup_custom_palette
    pop ax
    ret

; Programs exact 6-bit RGB DAC values (0-63) into VGA Palette Registers
setup_custom_palette:
    push ax
    push dx

    ; 1. Lighter Sky Blue for COL_SKY (Index 53 -> RGB: 32, 63, 63)
    mov dx, 0x03C8
    mov al, COL_SKY
    out dx, al
    inc dx
    mov al, 32                      ; R (Lighter Sky Tint)
    out dx, al
    mov al, 63                      ; G
    out dx, al
    mov al, 63                      ; B
    out dx, al

    ; 2. Star Coin Gold: 0xFFF9A825 -> R=249(62), G=168(42), B=37(9)
    mov dx, 0x03C8
    mov al, COL_STAR_GOLD
    out dx, al
    inc dx
    mov al, 62
    out dx, al
    mov al, 42
    out dx, al
    mov al, 9
    out dx, al

    ; 3. Rose: #FC94AF -> R=252(63), G=148(37), B=175(44)
    mov dx, 0x03C8
    mov al, COL_ROSE
    out dx, al
    inc dx
    mov al, 63
    out dx, al
    mov al, 37
    out dx, al
    mov al, 44
    out dx, al

    ; 4. Lemonade: #FCBACB -> R=252(63), G=186(46), B=203(51)
    mov dx, 0x03C8
    mov al, COL_LEMONADE
    out dx, al
    inc dx
    mov al, 63
    out dx, al
    mov al, 46
    out dx, al
    mov al, 51
    out dx, al

    ; 5. Lilac: #C8A2C8 -> R=200(50), G=162(40), B=200(50)
    mov dx, 0x03C8
    mov al, COL_LILAC
    out dx, al
    inc dx
    mov al, 50
    out dx, al
    mov al, 40
    out dx, al
    mov al, 50
    out dx, al

    ; 6. Periwinkle: #E9CFEC -> R=233(58), G=207(52), B=236(59)
    mov dx, 0x03C8
    mov al, COL_PERIWINKLE
    out dx, al
    inc dx
    mov al, 58
    out dx, al
    mov al, 52
    out dx, al
    mov al, 59
    out dx, al

    ; 7. Dark Blue Scoreboard: 0xFF0D47A1 -> R=13(3), G=71(18), B=161(40)
    mov dx, 0x03C8
    mov al, COL_HUD_BG
    out dx, al
    inc dx
    mov al, 3
    out dx, al
    mov al, 18
    out dx, al
    mov al, 40
    out dx, al

    pop dx
    pop ax
    ret


; clear_buffer - Fill the whole off-screen buffer with one colour (REP STOSW)
;   In: [bp+4]=colour | Out: buffer filled | Changes: none
clear_buffer:
    push bp
    mov bp, sp
    push ax
    push cx
    push di
    push es

    mov es, [buf_seg]
    xor di, di
    mov al, [bp+4]
    mov ah, al
    mov cx, 32000
    cld
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    pop bp
    ret 2


; flip_buffer - Copy the off-screen buffer to video memory (REP MOVSW)
;   In: none | Out: screen updated | Changes: none
flip_buffer:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ds, [cs:buf_seg]
    mov ax, 0xA000
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 32000
    cld
    rep movsw

    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret


; put_pixel - Write one clipped pixel into the buffer
;   In: [bp+8]=x, [bp+6]=y, [bp+4]=colour | Out: pixel set | Changes: none
put_pixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push di
    push es

    mov bx, [bp+8]
    cmp bx, 0
    jge $+5
    jmp near .out
    cmp bx, 320
    jl $+5
    jmp near .out
    mov ax, [bp+6]
    cmp ax, 0
    jge $+5
    jmp near .out
    cmp ax, 200
    jl $+5
    jmp near .out

    mov di, ax
    shl ax, 8
    shl di, 6
    add di, ax
    add di, bx

    mov es, [buf_seg]
    mov al, [bp+4]
    mov [es:di], al
.out:
    pop es
    pop di
    pop bx
    pop ax
    pop bp
    ret 6


; fill_rect - Fill a clipped rectangle in the buffer (REP STOSB per row)
;   In: [bp+12]=x, [bp+10]=y, [bp+8]=w, [bp+6]=h, [bp+4]=colour | Out: rectangle drawn | Changes: none
fill_rect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov es, [buf_seg]
    mov bx, [bp+12]                 ; x
    mov cx, [bp+8]                  ; width
    cmp bx, 0
    jl $+5
    jmp near .x_right
    add cx, bx                      ; clip the left edge
    xor bx, bx
.x_right:
    mov ax, bx
    add ax, cx
    cmp ax, 320
    jg $+5
    jmp near .x_ok
    mov cx, 320                     ; clip the right edge
    sub cx, bx
.x_ok:
    cmp cx, 0
    jg $+5
    jmp near .out
    mov dx, [bp+10]                 ; y
    mov ax, [bp+6]                  ; height
    cmp dx, 0
    jl $+5
    jmp near .y_bottom
    add ax, dx                      ; clip the top edge
    xor dx, dx
.y_bottom:
    mov di, dx
    add di, ax
    cmp di, 200
    jg $+5
    jmp near .y_ok
    mov ax, 200                     ; clip the bottom edge
    sub ax, dx
.y_ok:
    cmp ax, 0
    jg $+5
    jmp near .out

    mov di, dx
    shl dx, 8
    shl di, 6
    add di, dx
    add di, bx                      ; DI = y*320 + x
    mov dx, ax                      ; DX = rows to draw
    mov al, [bp+4]
    cld
.row_lp:
    push cx
    push di
    rep stosb
    pop di
    pop cx
    add di, 320
    dec dx
    jz $+5
    jmp near .row_lp
.out:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10


; MODULE 3: LEVEL MAP, TILE LOOKUP & RENDERING

; reset_map - Restore the working map from the original map (REP MOVSB)
;   In: none | Out: working_map restored | Changes: none
reset_map:
    push cx
    push si
    push di
    push es

    push ds
    pop es
    mov si, original_map
    mov di, working_map
    mov cx, MAP_SIZE
    cld
    rep movsb

    pop es
    pop di
    pop si
    pop cx
    ret

; Returns tile code at (world_px=[bp+6], world_py=[bp+4]) in AL, map index in BX

get_tile:
    push bp
    mov bp, sp
    push cx
    push dx

    mov ax, [bp+6]
    cmp ax, 0
    jge $+5
    jmp near .solid_wall
    shr ax, 4
    cmp ax, MAP_COLS
    jl $+5
    jmp near .solid_wall
    mov bx, ax

    mov ax, [bp+4]
    cmp ax, 0
    jge $+5
    jmp near .sky_tile
    shr ax, 4
    cmp ax, MAP_ROWS
    jl $+5
    jmp near .sky_tile

    mov cl, 60
    mul cl
    add bx, ax
    mov al, [working_map + bx]
    jmp near .done

.solid_wall:
    mov al, TILE_GROUND
    mov bx, 0
    jmp near .done
.sky_tile:
    mov al, TILE_SKY
    mov bx, 0
.done:
    pop dx
    pop cx
    pop bp
    ret 4

; Checks if tile code in AL is solid (Returns AL=1 if solid, 0 if not)

is_tile_solid:
    cmp al, TILE_GROUND
    jae $+5
    jmp near .not_solid
    cmp al, TILE_STAIR
    ja $+5
    jmp near .solid
.not_solid:
    xor al, al
    ret
.solid:
    mov al, 1
    ret


; draw_tile - Draw one 16x16 tile
;   In: [bp+8]=screen x, [bp+6]=screen y, [bp+4]=tile code | Out: tile drawn | Changes: none
draw_tile:
    push bp
    mov bp, sp
    push ax
    push bx

    mov al, [bp+4]
    cmp al, TILE_SKY
    jne $+5
    jmp near .done

    ; Dark Green Ground with Light Green Grass Top
    cmp al, TILE_GROUND
    je $+5
    jmp near .chk_brick
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_DIRT
    call fill_rect
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 3
    push word COL_LGREEN
    call fill_rect
    jmp near .done

.chk_brick:
    ; Rose (#FC94AF) + Lemonade (#FCBACB) Combination
    cmp al, TILE_BRICK
    je $+5
    jmp near .chk_q
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_ROSE
    call fill_rect
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 2
    push word COL_LEMONADE
    call fill_rect
    mov ax, [bp+6]
    add ax, 8
    push word [bp+8]
    push ax
    push word 16
    push word 1
    push word COL_LEMONADE
    call fill_rect
    jmp near .done

.chk_q:
    ; Lemonade (#FCBACB) + Rose (#FC94AF) Combination
    cmp al, TILE_Q_COIN
    jne $+5
    jmp near .draw_q
    cmp al, TILE_Q_MUSH
    je $+5
    jmp near .chk_empty
.draw_q:
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_LEMONADE
    call fill_rect
    mov bx, [bp+8]
    add bx, 2
    mov ax, [bp+6]
    add ax, 2
    push bx
    push ax
    push word 12
    push word 12
    push word COL_ROSE
    call fill_rect
    mov bx, [bp+8]
    add bx, 4
    mov ax, [bp+6]
    add ax, 4
    push bx
    push ax
    push word COL_WHITE
    push word '?'
    call draw_char
    jmp near .done

.chk_empty:
    cmp al, TILE_EMPTY
    je $+5
    jmp near .chk_stair
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_GRAY
    call fill_rect
    jmp near .done

.chk_stair:
    cmp al, TILE_STAIR
    je $+5
    jmp near .chk_pipe
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_ORANGE
    call fill_rect
    jmp near .done

.chk_pipe:
    ; Obstacle Pipes: Lilac (#C8A2C8) + Periwinkle (#E9CFEC) Combination
    cmp al, TILE_PIPE_TL
    jae $+5
    jmp near .chk_coin
    cmp al, TILE_PIPE_BR
    jbe $+5
    jmp near .chk_coin
    push word [bp+8]
    push word [bp+6]
    push word 16
    push word 16
    push word COL_LILAC
    call fill_rect
    mov bx, [bp+8]
    add bx, 2
    push bx
    push word [bp+6]
    push word 3
    push word 16
    push word COL_PERIWINKLE
    call fill_rect
    jmp near .done

.chk_coin:
    ; Star-Shaped Coin with Color 0xFFF9A825 (COL_STAR_GOLD)
    cmp al, TILE_COIN
    je $+5
    jmp near .chk_flag
    push word [bp+8]
    push word [bp+6]
    push word spr_star
    push word 0
    call draw_sprite
    jmp near .done

.chk_flag:
    cmp al, TILE_FLAG
    je $+5
    jmp near .done
    mov bx, [bp+8]
    add bx, 7
    push bx
    push word [bp+6]
    push word 2
    push word 16
    push word COL_LGREEN
    call fill_rect

.done:
    pop bx
    pop ax
    pop bp
    ret 6


; draw_visible_map - Draw the 20+1 visible tile columns, scrolled by camera_x
;   In: none (uses camera_x) | Out: map drawn | Changes: none
draw_visible_map:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov ax, [camera_x]
    mov bx, ax
    shr bx, 4
    and ax, 0x000F
    neg ax
    mov si, ax

    mov cx, 21
.col_lp:
    cmp bx, MAP_COLS
    jl $+5
    jmp near .done_cols
    mov di, 1
.row_lp:
    cmp di, MAP_ROWS
    jl $+5
    jmp near .next_col

    mov ax, di
    mov dl, 60
    mul dl
    add ax, bx
    push bx
    mov bx, ax
    mov dl, [working_map + bx]
    pop bx

    mov ax, di
    shl ax, 4
    push si
    push ax
    xor dh, dh
    push dx
    call draw_tile

    inc di
    jmp near .row_lp
.next_col:
    add si, 16
    inc bx
    dec cx
    jz $+5
    jmp near .col_lp
.done_cols:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret


; MODULE 4: SPRITE RENDERER

; draw_sprite - Draw a 16x16 sprite, colour 0 transparent (flags: bit0 mirror, bit1 double height)
;   In: [bp+10]=x, [bp+8]=y, [bp+6]=sprite address, [bp+4]=flags | Out: sprite drawn | Changes: none
draw_sprite:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, [bp+6]
    mov dx, [bp+8]
    mov cx, 16
    test word [bp+4], 2             ; bit 1 = stretch to 16x32
    jnz $+5
    jmp near .row_lp
    mov cx, 32
.row_lp:
    push cx
    xor di, di
.col_lp:
    mov bx, di
    test word [bp+4], 1
    jnz $+5
    jmp near .no_flip
    mov bx, 15
    sub bx, di
.no_flip:
    mov al, [si + bx]
    cmp al, COL_TRANS
    jne $+5
    jmp near .skip_px
    mov bx, [bp+10]
    add bx, di
    push bx
    push dx
    xor ah, ah
    push ax
    call put_pixel
.skip_px:
    inc di
    cmp di, 16
    jae $+5
    jmp near .col_lp
    test word [bp+4], 2
    jnz $+5
    jmp near .next_src
    test cl, 1                      ; stretched: use each source row twice
    jnz $+5
    jmp near .skip_src
.next_src:
    add si, 16
.skip_src:
    inc dx
    pop cx
    dec cx
    jz $+5
    jmp near .row_lp

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 8


; MODULE 6: CAMERA UPDATE

; update_camera - Follow Baby Peach, clamp, never scroll left, left wall (Section 5.3)
;   In: none (uses mario_x) | Out: camera_x, mario_x updated | Changes: none
update_camera:
    push ax
    push bx

    mov ax, [mario_x]
    mov bx, [camera_x]
    cmp ax, bx
    jl $+5
    jmp near .chk_scroll
    mov [mario_x], bx
    mov word [mario_vx], 0
    jmp near .done

.chk_scroll:
    sub ax, bx
    cmp ax, 160
    jg $+5
    jmp near .done
    mov ax, [mario_x]
    sub ax, 160
    cmp ax, MAX_CAMERA_X
    jg $+5
    jmp near .set_cam
    mov ax, MAX_CAMERA_X
.set_cam:
    cmp ax, [camera_x]
    jg $+5
    jmp near .done
    mov [camera_x], ax
.done:
    pop bx
    pop ax
    ret

; =============================================================================
; MODULE 7 & 8: INTERRUPT HANDLERS (30 Hz PIT Timer + Keyboard)
; =============================================================================
; -----------------------------------------------------------------------------
; kb_isr - INT 09h handler: keeps key_state (held) and key_edge (new press) tables
;   In: port 60h | Out: tables updated | Changes: none (all saved)
kb_isr:
    push ax
    push bx
    push ds
    push cs
    pop ds

    in al, 0x60
    cmp al, 0xE0
    jne $+5
    jmp near .eoi
    mov bl, al
    and bx, 0x007F
    test al, 0x80
    jz $+5
    jmp near .rel
    cmp byte [key_state + bx], 0
    je $+5
    jmp near .held
    mov byte [key_edge + bx], 1
.held:
    mov byte [key_state + bx], 1
    jmp near .eoi
.rel:
    mov byte [key_state + bx], 0
.eoi:
    mov al, 0x20
    out 0x20, al
    pop ds
    pop bx
    pop ax
    iret


; timer_isr - INT 08h handler: counts a tick, then chains to the old handler
;   In: none | Out: tick_count + 1 | Changes: none
timer_isr:
    push ds
    push cs
    pop ds
    inc word [tick_count]
    pop ds
    jmp far [cs:old_tm_isr]


hook_interrupts:
    push ax
    push bx
    push dx
    push es

    mov ax, 0x3509
    int 0x21
    mov [old_kb_isr], bx
    mov [old_kb_isr+2], es

    mov ax, 0x3508
    int 0x21
    mov [old_tm_isr], bx
    mov [old_tm_isr+2], es

    cli
    ; Set PIT Channel 0 to ~30 Hz (1193182 / 39773 = 30.0 Hz)
    mov al, 0x36
    out 0x43, al
    mov ax, 39773
    out 0x40, al
    mov al, ah
    out 0x40, al

    mov dx, kb_isr
    mov ax, 0x2509
    int 0x21
    mov dx, timer_isr
    mov ax, 0x2508
    int 0x21
    sti

    pop es
    pop dx
    pop bx
    pop ax
    ret


unhook_interrupts:
    push ax
    push dx
    push ds
    cli
    ; Restore PIT Channel 0 to default 18.2 Hz (divisor 0 = 65536)
    mov al, 0x36
    out 0x43, al
    xor al, al
    out 0x40, al
    out 0x40, al

    lds dx, [cs:old_kb_isr]
    mov ax, 0x2509
    int 0x21
    lds dx, [cs:old_tm_isr]
    mov ax, 0x2508
    int 0x21
    sti
    pop ds
    pop dx
    pop ax
    ret


; MODULE 9 & 10: PLAYER PHYSICS, COLLISION & BLOCK TRIGGERS

; update_mario_physics - Move Baby Peach: speed, jump, gravity, tile collision, map coins
;   In: none (uses key_state) | Out: mario_* variables updated | Changes: none
update_mario_physics:
    push ax
    push bx
    push cx
    push dx
    push si

    mov ax, [mario_y]
    mov [mario_prev_y], ax

    ; 1. Horizontal Speed (Walk / Run / Friction)
    mov cx, MAX_WALK
    cmp byte [key_state + KEY_LSHIFT], 1
    je $+5
    jmp near .chk_left
    mov cx, MAX_RUN
.chk_left:
    cmp byte [key_state + KEY_LEFT], 1
    je $+5
    jmp near .chk_right
    mov byte [mario_dir], 1
    mov ax, [mario_vx]
    sub ax, WALK_ACCEL
    mov bx, cx
    neg bx
    cmp ax, bx
    jl $+5
    jmp near .set_vx
    mov ax, bx
    jmp near .set_vx
.chk_right:
    cmp byte [key_state + KEY_RIGHT], 1
    je $+5
    jmp near .do_friction
    mov byte [mario_dir], 0
    mov ax, [mario_vx]
    add ax, WALK_ACCEL
    cmp ax, cx
    jg $+5
    jmp near .set_vx
    mov ax, cx
    jmp near .set_vx
.do_friction:
    mov ax, [mario_vx]
    cmp ax, 0
    jne $+5
    jmp near .set_vx
    jle $+5
    jmp near .fric_pos
    add ax, FRICTION
    cmp ax, 0
    jg $+5
    jmp near .set_vx
    xor ax, ax
    jmp near .set_vx
.fric_pos:
    sub ax, FRICTION
    cmp ax, 0
    jl $+5
    jmp near .set_vx
    xor ax, ax
.set_vx:
    mov [mario_vx], ax

    ; 2. Apply Horizontal Velocity (8.8 fixed point -> integer + subpixel)
    mov ax, [mario_vx]
    add [mario_x_sub], al
    mov al, ah
    cbw
    adc [mario_x], ax

    ; Clamp X to [camera_x .. WORLD_MAX_X]
    mov ax, [camera_x]
    cmp [mario_x], ax
    jl $+5
    jmp near .chk_max_x
    mov [mario_x], ax
    mov word [mario_vx], 0
.chk_max_x:
    cmp word [mario_x], WORLD_MAX_X
    jg $+5
    jmp near .coll_x
    mov word [mario_x], WORLD_MAX_X
    mov word [mario_vx], 0

.coll_x:
    ; Horizontal Tile Collision (Check front edge at top+2 and feet-2)
    mov dx, 16
    cmp byte [mario_hp], 2
    je $+5
    jmp near .got_h1
    mov dx, 32
.got_h1:
    cmp word [mario_vx], 0
    jne $+5
    jmp near .jump_logic
    jge $+5
    jmp near .check_left_wall

    ; Moving Right: test X + 14
    mov cx, [mario_x]
    add cx, 14
    mov si, [mario_y]
    add si, 2
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    jne $+5
    jmp near .hit_right_wall

    mov si, [mario_y]
    add si, dx
    sub si, 2
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    je $+5
    jmp near .jump_logic
.hit_right_wall:
    and cx, 0xFFF0
    sub cx, 15
    mov [mario_x], cx
    mov word [mario_vx], 0
    jmp near .jump_logic

.check_left_wall:
    ; Moving Left: test X + 2
    mov cx, [mario_x]
    add cx, 2
    mov si, [mario_y]
    add si, 2
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    jne $+5
    jmp near .hit_left_wall

    mov si, [mario_y]
    add si, dx
    sub si, 2
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    je $+5
    jmp near .jump_logic
.hit_left_wall:
    and cx, 0xFFF0
    add cx, 14
    mov [mario_x], cx
    mov word [mario_vx], 0

.jump_logic:
    ; 3. Jump & Variable Jump Height (Section 5.2)
    cmp byte [key_state + KEY_SPACE], 1
    je $+5
    jmp near .chk_cutoff
    cmp byte [mario_on_ground], 1
    je $+5
    jmp near .gravity_step
    mov word [mario_vy], JUMP_VEL
    mov byte [mario_on_ground], 0
    jmp near .gravity_step

.chk_cutoff:
    mov ax, [mario_vy]
    cmp ax, JUMP_CUTOFF             ; Both negative: if vy < -2.0 (rising fast)
    jl $+5
    jmp near .gravity_step
    mov word [mario_vy], JUMP_CUTOFF

.gravity_step:
    mov ax, [mario_vy]
    add ax, GRAVITY
    cmp ax, MAX_FALL
    jg $+5
    jmp near .set_vy
    mov ax, MAX_FALL
.set_vy:
    mov [mario_vy], ax

    ; Apply Vertical Velocity
    add [mario_y_sub], al
    mov al, ah
    cbw
    adc [mario_y], ax

    mov byte [mario_on_ground], 0
    mov dx, 16
    cmp byte [mario_hp], 2
    je $+5
    jmp near .got_h2
    mov dx, 32
.got_h2:
    cmp word [mario_vy], 0
    jge $+5
    jmp near .check_ceiling

    ; Falling: Check feet at (X+3, Y+height) and (X+12, Y+height)
    mov si, [mario_y]
    add si, dx
    mov cx, [mario_x]
    add cx, 3
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    jne $+5
    jmp near .land_on_floor

    mov cx, [mario_x]
    add cx, 12
    push cx
    push si
    call get_tile
    call is_tile_solid
    cmp al, 1
    je $+5
    jmp near .check_map_coin
.land_on_floor:
    and si, 0xFFF0
    sub si, dx
    mov [mario_y], si
    mov byte [mario_y_sub], 0
    mov word [mario_vy], 0
    mov byte [mario_on_ground], 1
    mov word [stomp_chain], 0
    jmp near .check_map_coin

.check_ceiling:
    ; Rising: Check head center (X+8, Y)
    mov cx, [mario_x]
    add cx, 8
    mov si, [mario_y]
    push cx
    push si
    call get_tile                   ; AL = tile code, BX = map index
    push ax
    call is_tile_solid
    cmp al, 1
    pop ax
    je $+5
    jmp near .check_map_coin

    ; Solid block hit from below!
    mov word [mario_vy], 0
    and si, 0xFFF0
    add si, 16
    mov [mario_y], si
    push ax
    push bx
    call trigger_block_hit

.check_map_coin:
    ; Check if Baby Peach overlaps a free map coin (TILE_COIN = 11)
    mov cx, [mario_x]
    add cx, 8
    mov si, [mario_y]
    add si, 8
    push cx
    push si
    call get_tile
    cmp al, TILE_COIN
    je $+5
    jmp near .done_phys
    mov byte [working_map + bx], TILE_SKY
    call collect_coin

.done_phys:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; =============================================================================
; MODULE 12: BLOCKS, COINS & MUSHROOM POWER-UP (Section 5.9)
; =============================================================================
; Inputs: [bp+6]=tile_code, [bp+4]=working_map_index
; -----------------------------------------------------------------------------
; trigger_block_hit - React to a head hit: break brick, release coin or mushroom
;   In: [bp+6]=tile code, [bp+4]=map index | Out: working_map changed | Changes: none
trigger_block_hit:
    push bp
    mov bp, sp
    push ax
    push bx
    push dx

    mov al, [bp+6]
    mov bx, [bp+4]

    cmp al, TILE_BRICK
    je $+5
    jmp near .chk_q_coin
    cmp byte [mario_hp], 2          ; Only Super Baby Peach breaks bricks
    je $+5
    jmp near .done
    mov byte [working_map + bx], TILE_SKY
    push word 50
    call add_score
    jmp near .done

.chk_q_coin:
    cmp al, TILE_Q_COIN
    je $+5
    jmp near .chk_q_mush
    mov byte [working_map + bx], TILE_EMPTY
    call collect_coin
    jmp near .done

.chk_q_mush:
    cmp al, TILE_Q_MUSH
    je $+5
    jmp near .done
    mov byte [working_map + bx], TILE_EMPTY
    ; Compute pixel coordinates of block from index BX (row = BX/60, col = BX%60)
    mov ax, bx
    mov dl, 60
    div dl                          ; AL = row, AH = col
    xor bx, bx
    mov bl, ah
    shl bx, 4                       ; mush_x = col * 16
    mov [mush_x], bx
    xor ah, ah
    dec ax                          ; 1 row above block
    shl ax, 4
    mov [mush_y], ax
    mov word [mush_vy], 0
    mov byte [mush_dir], 0
    mov byte [mush_active], 1

.done:
    pop dx
    pop bx
    pop ax
    pop bp
    ret 4

; -----------------------------------------------------------------------------
; collect_coin - Add a coin: +200 score, coins +1, extra life at 100
;   In: none | Out: score, coins, lives updated | Changes: none
collect_coin:
    push ax
    push word 200
    call add_score
    inc byte [coins]
    cmp byte [coins], 100
    jae $+5
    jmp near .done
    mov byte [coins], 0
    cmp byte [lives], 99
    jb $+5
    jmp near .done
    inc byte [lives]
.done:
    pop ax
    ret


; update_mushroom - Move the mushroom: walk, turn at walls, fall, remove
;   In: none | Out: mush_* updated | Changes: none
update_mushroom:
    cmp byte [mush_active], 1
    je $+5
    jmp near .ret
    push ax
    push bx
    push cx

    ; Move horizontally 1 px/frame
    cmp byte [mush_dir], 0
    je $+5
    jmp near .move_left
    inc word [mush_x]
    mov cx, [mush_x]
    add cx, 15
    jmp near .chk_wall
.move_left:
    dec word [mush_x]
    mov cx, [mush_x]
.chk_wall:
    mov ax, [mush_y]
    add ax, 8
    push cx
    push ax
    call get_tile
    call is_tile_solid
    cmp al, 1
    je $+5
    jmp near .fall
    xor byte [mush_dir], 1          ; Reverse direction at wall

.fall:
    ; Gravity on mushroom
    mov ax, [mush_y]
    add ax, 16
    mov cx, [mush_x]
    add cx, 8
    push cx
    push ax
    call get_tile
    call is_tile_solid
    cmp al, 1
    jne $+5
    jmp near .on_floor
    add word [mush_y], 2
    jmp near .chk_bounds
.on_floor:
    mov ax, [mush_y]                ; AX was destroyed by get_tile, reload it
    add ax, 16
    and ax, 0xFFF0
    sub ax, 16
    mov [mush_y], ax

.chk_bounds:
    cmp word [mush_y], 192
    jl $+5
    jmp near .kill_mush
    mov ax, [camera_x]
    sub ax, 32
    cmp [mush_x], ax
    jl $+5
    jmp near .done
.kill_mush:
    mov byte [mush_active], 0
.done:
    pop cx
    pop bx
    pop ax
.ret:
    ret


; MODULE 11: ENEMIES & KOOPA SHELLS (Section 5.5)

; spawn_enemies - Fill the enemy table from the spawn table
;   In: none | Out: enemy_table filled | Changes: none
spawn_enemies:
    push ax
    push bx
    push cx
    push si
    push di

    ; Clear enemy table
    mov di, enemy_table
    mov cx, 96
.clr:
    mov byte [di], 0
    inc di
    dec cx
    jz $+5
    jmp near .clr

    mov si, enemy_spawns
    mov di, enemy_table
.next_sp:
    mov al, [si]
    cmp al, 0
    jne $+5
    jmp near .done
    mov [di+0], al                  ; type
    mov byte [di+1], 1              ; state 1 = idle until camera nears
    xor ah, ah
    mov al, [si+1]
    shl ax, 4
    mov [di+2], ax                  ; world_x = col * 16
    xor ah, ah
    mov al, [si+2]
    shl ax, 4
    mov [di+4], ax                  ; world_y = row * 16
    mov byte [di+6], 0              ; x_sub
    mov byte [di+7], 0              ; dir = 0 (walk left initially)
    mov word [di+8], 0              ; timer
    add si, 3
    add di, 12
    jmp near .next_sp
.done:
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    ret


; update_enemies - Update every enemy record: activate, walk, turn, fall, remove
;   In: none | Out: enemy_table updated | Changes: none
update_enemies:
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, enemy_table
    mov cx, MAX_ENEMIES
.loop_en:
    push cx
    mov al, [si+1]                  ; state
    cmp al, 0
    jne $+5
    jmp near .next_en

    ; Check activation: within 1 tile (336 px) of camera
    cmp al, 1
    je $+5
    jmp near .active_en
    mov ax, [camera_x]
    add ax, 336
    cmp [si+2], ax
    jle $+5
    jmp near .next_en
    mov byte [si+1], 2              ; Activate -> walking!

.active_en:
    mov al, [si+1]
    cmp al, 3                       ; Flattened Goomba or Stationary Shell
    je $+5
    jmp near .chk_move
    cmp byte [si+0], 1              ; Goomba?
    je $+5
    jmp near .shell_grace
    dec word [si+8]
    jz $+5
    jmp near .next_en
    mov byte [si+1], 0              ; Remove flattened Goomba after 1s
    jmp near .next_en
.shell_grace:
    cmp word [si+8], 0
    jne $+5
    jmp near .next_en
    dec word [si+8]
    jmp near .next_en

.chk_move:
    ; Decrement shell grace timer if sliding
    cmp word [si+8], 0
    jne $+5
    jmp near .do_speed
    dec word [si+8]
.do_speed:
    ; Select speed based on type & state
    mov dx, GOOMBA_SPEED
    cmp byte [si+0], 2
    je $+5
    jmp near .chk_slide_spd
    mov dx, KOOPA_SPEED
.chk_slide_spd:
    cmp byte [si+1], 4              ; Sliding shell
    je $+5
    jmp near .apply_dir
    mov dx, SHELL_SPEED

.apply_dir:
    cmp byte [si+7], 0              ; 0 = moving left, 1 = moving right
    je $+5
    jmp near .move_r
    neg dx
.move_r:
    add [si+6], dl
    mov al, dh
    cbw
    adc [si+2], ax

    ; Wall collision check
    mov bx, [si+2]
    cmp byte [si+7], 0
    jne $+5
    jmp near .wall_l
    add bx, 15
.wall_l:
    mov ax, [si+4]
    add ax, 8
    push bx
    push ax
    call get_tile
    call is_tile_solid
    cmp al, 1
    je $+5
    jmp near .gravity_en
    xor byte [si+7], 1              ; Turn around at wall

.gravity_en:
    cmp byte [si+1], 2              ; walking enemies turn around at other enemies
    je $+5
    jmp near .grav_go
    call check_enemy_bump
.grav_go:
    ; Check ground beneath enemy
    mov bx, [si+2]
    add bx, 8
    mov ax, [si+4]
    add ax, 16
    push bx
    push ax
    call get_tile
    call is_tile_solid
    cmp al, 1
    jne $+5
    jmp near .en_on_ground

    ; If walking Koopa reaches a ledge, turn around (Section 5.5)
    cmp byte [si+0], 2
    je $+5
    jmp near .fall_down
    cmp byte [si+1], 2
    je $+5
    jmp near .fall_down
    xor byte [si+7], 1
    jmp near .chk_shell_kills

.fall_down:
    add word [si+4], 2
    cmp word [si+4], 192
    jge $+5
    jmp near .chk_shell_kills
    mov byte [si+1], 0              ; Fell into pit -> remove
    jmp near .next_en

.en_on_ground:
    mov ax, [si+4]                  ; AX was destroyed by get_tile, reload it
    add ax, 16
    and ax, 0xFFF0
    sub ax, 16
    mov [si+4], ax

.chk_shell_kills:
    ; If sliding shell (state 4), check overlap with other enemies (+500 pts)
    cmp byte [si+1], 4
    je $+5
    jmp near .chk_left_behind
    call check_shell_vs_enemies

.chk_left_behind:
    ; Remove enemy if > 32px left of camera
    mov ax, [camera_x]
    sub ax, 32
    cmp [si+2], ax
    jg $+5
    jmp near .remove_en
    jmp near .next_en
.remove_en:
    mov byte [si+1], 0

.next_en:
    add si, 12
    pop cx
    dec cx
    jz $+5
    jmp near .loop_en

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; SI = walking enemy record. Flips its direction when it walks into
; another walking enemy (only the one that moves towards the other turns).

; check_enemy_bump - Turn a walking enemy around when it walks into another one
;   In: SI=enemy record | Out: direction byte flipped | Changes: none
check_enemy_bump:
    push ax
    push cx
    push di

    mov di, enemy_table
    mov cx, MAX_ENEMIES
.lp:
    cmp di, si
    jne $+5
    jmp near .nxt
    cmp byte [di+1], 2
    je $+5
    jmp near .nxt
    mov ax, [di+4]
    sub ax, [si+4]
    cmp ax, 8
    jle $+5
    jmp near .nxt
    cmp ax, -8
    jge $+5
    jmp near .nxt
    mov ax, [di+2]
    sub ax, [si+2]                  ; AX = other.x - my.x
    cmp ax, 14
    jle $+5
    jmp near .nxt
    cmp ax, -14
    jge $+5
    jmp near .nxt
    cmp byte [si+7], 0              ; 0 = I walk left
    je $+5
    jmp near .walk_right
    cmp ax, 0
    jl $+5
    jmp near .nxt                        ; other is behind me: ignore
    jmp near .turn
.walk_right:
    cmp ax, 0
    jg $+5
    jmp near .nxt
.turn:
    xor byte [si+7], 1
    jmp near .done
.nxt:
    add di, 12
    dec cx
    jz $+5
    jmp near .lp
.done:
    pop di
    pop cx
    pop ax
    ret

; SI = sliding shell record

; check_shell_vs_enemies - A sliding shell defeats every enemy it touches (+500 each)
;   In: SI=sliding shell record | Out: enemies removed, score | Changes: none
check_shell_vs_enemies:
    push ax
    push bx
    push cx
    push di

    mov di, enemy_table
    mov cx, MAX_ENEMIES
.lp:
    cmp di, si
    jne $+5
    jmp near .nxt
    cmp byte [di+1], 0
    jne $+5
    jmp near .nxt
    ; Simple 14x14 overlap test
    mov ax, [si+2]
    sub ax, [di+2]
    cmp ax, -14
    jge $+5
    jmp near .nxt
    cmp ax, 14
    jle $+5
    jmp near .nxt
    mov ax, [si+4]
    sub ax, [di+4]
    cmp ax, -14
    jge $+5
    jmp near .nxt
    cmp ax, 14
    jle $+5
    jmp near .nxt

    mov byte [di+1], 0              ; Defeat enemy
    push word 500
    call add_score
.nxt:
    add di, 12
    dec cx
    jz $+5
    jmp near .lp

    pop di
    pop cx
    pop bx
    pop ax
    ret


; MODULE 10 & 11: BABY PEACH VS ENTITIES COLLISION (Section 5.6, 5.7)

; check_entity_collisions - Baby Peach against mushroom and enemies: collect, stomp, kick, hurt
;   In: none | Out: hp, score, enemy states | Changes: none
check_entity_collisions:
    push ax
    push bx
    push cx
    push dx
    push si

    mov dx, 16
    cmp byte [mario_hp], 2
    je $+5
    jmp near .got_h
    mov dx, 32
.got_h:
    ; 1. Check Mushroom Overlap
    cmp byte [mush_active], 1
    je $+5
    jmp near .chk_enemies
    mov ax, [mario_x]
    add ax, 14
    cmp ax, [mush_x]
    jae $+5
    jmp near .chk_enemies
    mov ax, [mush_x]
    add ax, 14
    cmp ax, [mario_x]
    jae $+5
    jmp near .chk_enemies
    mov ax, [mario_y]
    add ax, dx
    cmp ax, [mush_y]
    jae $+5
    jmp near .chk_enemies
    mov ax, [mush_y]
    add ax, 16
    cmp ax, [mario_y]
    jae $+5
    jmp near .chk_enemies

    ; Collected Mushroom! (+1000, Small -> Super with feet fixed)
    mov byte [mush_active], 0
    push word 1000
    call add_score
    cmp byte [mario_hp], 1
    je $+5
    jmp near .chk_enemies
    mov byte [mario_hp], 2
    sub word [mario_y], 16          ; Keep feet fixed: y_top = y_feet - 32

.chk_enemies:
    mov si, enemy_table
    mov cx, MAX_ENEMIES
.en_loop:
    mov al, [si+1]
    cmp al, 2                       ; Only active states (2=walk, 3=flat/stat, 4=slide)
    jae $+5
    jmp near .next_en
    ; Ignore flattened Goomba
    cmp byte [si+0], 1
    je $+5
    jmp near .test_box
    cmp al, 3
    jne $+5
    jmp near .next_en

.test_box:
    ; Rectangle overlap test
    mov ax, [mario_x]
    add ax, 13
    cmp ax, [si+2]
    jg $+5
    jmp near .next_en
    mov ax, [si+2]
    add ax, 13
    cmp ax, [mario_x]
    jg $+5
    jmp near .next_en

    mov ax, [mario_y]
    add ax, dx
    cmp ax, [si+4]
    jg $+5
    jmp near .next_en
    mov ax, [si+4]
    add ax, 16
    cmp ax, [mario_y]
    jg $+5
    jmp near .next_en

    ; Overlap detected! Ignore enemy while its grace timer runs
    cmp word [si+8], 0
    je $+5
    jmp near .next_en
    cmp byte [si+0], 2
    je $+5
    jmp near .chk_stomp
    cmp byte [si+1], 3
    je $+5
    jmp near .chk_stomp
    ; Kick stationary shell (+400 pts, 8-frame grace)
    mov byte [si+1], 4
    mov word [si+8], 8
    mov byte [si+7], 1              ; Kick right
    mov ax, [mario_x]
    cmp ax, [si+2]
    jg $+5
    jmp near .kicked
    mov byte [si+7], 0              ; Kick left
.kicked:
    push word 400
    call add_score
    jmp near .next_en

.chk_stomp:
    ; Stomp test: Baby Peach moving down (vy > 0) AND prev_feet <= enemy_y + 10
    cmp word [mario_vy], 0
    jg $+5
    jmp near .side_hit
    mov ax, [mario_prev_y]
    add ax, dx
    mov bx, [si+4]
    add bx, 10
    cmp ax, bx
    jle $+5
    jmp near .side_hit

    ; --- STOMP SUCCESS ---
    mov word [mario_vy], STOMP_BOUNCE
    cmp byte [key_state + KEY_SPACE], 1
    je $+5
    jmp near .stomp_pts
    mov word [mario_vy], JUMP_VEL   ; Higher bounce if Space held
.stomp_pts:
    call award_stomp_chain
    cmp byte [si+0], 1              ; Goomba?
    je $+5
    jmp near .stomp_koopa
    mov byte [si+1], 3              ; Flattened state
    mov word [si+8], 30             ; ~1 second display at 30 FPS
    jmp near .next_en
.stomp_koopa:
    mov byte [si+1], 3              ; Koopa or sliding shell becomes stationary shell
    mov word [si+8], 8
    jmp near .next_en

.side_hit:
    ; Side or bottom contact -> Hurt Baby Peach unless invulnerable
    cmp word [mario_invuln], 0
    je $+5
    jmp near .next_en
    cmp byte [mario_hp], 2
    jne $+5
    jmp near .shrink_mario
    mov byte [mario_hp], 0          ; Small Baby Peach dies
    jmp near .done
.shrink_mario:
    mov byte [mario_hp], 1
    add word [mario_y], 16          ; Keep feet fixed (32 -> 16)
    mov word [mario_invuln], 60     ; ~2 seconds invulnerability blink at 30 FPS

.next_en:
    add si, 12
    dec cx
    jz $+5
    jmp near .en_loop

.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -----------------------------------------------------------------------------
; award_stomp_chain - Give stomp-chain points (or a 1-UP after 10 stomps)
;   In: none | Out: score or lives, chain + 1 | Changes: none
award_stomp_chain:
    push ax
    push bx
    mov bx, [stomp_chain]
    inc word [stomp_chain]
    cmp bx, 10
    jb $+5
    jmp near .one_up
    shl bx, 1
    mov ax, [stomp_table + bx]
    push ax
    call add_score
    jmp near .done
.one_up:
    cmp byte [lives], 99
    jb $+5
    jmp near .done
    inc byte [lives]
.done:
    pop bx
    pop ax
    ret

; Flag Pole Scoring (Section 5.4 & 5.11)
; -----------------------------------------------------------------------------
; trigger_flag_win - Add the flag points by height and start the win sequence
;   In: none | Out: score, game_state=WIN | Changes: none
trigger_flag_win:
    push ax
    push bx

    mov ax, [mario_y]
    cmp byte [mario_hp], 2
    je $+5
    jmp near .calc_row
    add ax, 16
.calc_row:
    shr ax, 4                       ; Row of Baby Peach's feet
    mov bx, 100
    cmp ax, 3
    jbe $+5
    jmp near .r4
    mov bx, 5000
    jmp near .add_f
.r4:
    cmp ax, 4
    jbe $+5
    jmp near .r5
    mov bx, 2000
    jmp near .add_f
.r5:
    cmp ax, 5
    jbe $+5
    jmp near .r7
    mov bx, 800
    jmp near .add_f
.r7:
    cmp ax, 7
    jbe $+5
    jmp near .add_f
    mov bx, 400
.add_f:
    push bx
    call add_score
    mov word [mario_x], 892
    mov word [state_timer], 90      ; slide + walk, about 3 s at 30 FPS
    mov word [game_state], ST_WIN_SEQ

    pop bx
    pop ax
    ret


; MODULE 13: 32-BIT SCORE, FONT RENDERING & HUD (Section 5.14)

; Inputs: [bp+4] = 16-bit points to add to 32-bit score (ADD / ADC)

; add_score - Add points to the 32-bit score with ADD/ADC, clamp to 999999
;   In: [bp+4]=points | Out: score_high:score_low | Changes: none
add_score:
    push bp
    mov bp, sp
    push ax

    mov ax, [bp+4]
    add [score_low], ax
    adc word [score_high], 0

    ; Clamp to 999,999 (0x000F423F)
    cmp word [score_high], 0x000F
    jae $+5
    jmp near .done
    jbe $+5
    jmp near .clamp
    cmp word [score_low], 0x423F
    ja $+5
    jmp near .done
.clamp:
    mov word [score_high], 0x000F
    mov word [score_low], 0x423F
.done:
    pop ax
    pop bp
    ret 2

; Draws an 8x8 ASCII character from ROM BIOS font (F000:FA6E)
; Inputs: [bp+10]=x, [bp+8]=y, [bp+6]=color, [bp+4]=ASCII char

draw_char:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov ax, 0xF000
    mov es, ax
    mov al, [bp+4]
    xor ah, ah
    shl ax, 3
    mov si, 0xFA6E
    add si, ax

    mov dx, [bp+8]                  ; Y
    mov cx, 8
.row_lp:
    push cx
    mov al, [es:si]
    mov bx, [bp+10]                 ; X
    mov cx, 8
.bit_lp:
    shl al, 1
    jc $+5
    jmp near .skip
    push ax
    push bx
    push dx
    push word [bp+6]
    call put_pixel
    pop ax
.skip:
    inc bx
    dec cx
    jz $+5
    jmp near .bit_lp
    inc si
    inc dx
    pop cx
    dec cx
    jz $+5
    jmp near .row_lp

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 8

; Inputs: [bp+10]=x, [bp+8]=y, [bp+6]=color, [bp+4]=null-terminated string addr

; draw_string - Draw a zero-terminated string
;   In: [bp+10]=x, [bp+8]=y, [bp+6]=colour, [bp+4]=string address | Out: text drawn | Changes: none
draw_string:
    push bp
    mov bp, sp
    push ax
    push bx
    push si

    mov bx, [bp+10]
    mov si, [bp+4]
.lp:
    mov al, [si]
    cmp al, 0
    jne $+5
    jmp near .done
    push bx
    push word [bp+8]
    push word [bp+6]
    xor ah, ah
    push ax
    call draw_char
    add bx, 8
    inc si
    jmp near .lp
.done:
    pop si
    pop bx
    pop ax
    pop bp
    ret 8

; Converts 16-bit number to zero-padded decimal digits via stack (Module 13)
; Inputs: [bp+12]=x, [bp+10]=y, [bp+8]=number, [bp+6]=digits_count, [bp+4]=color

; draw_number - Draw an unsigned number with leading zeros
;   In: [bp+12]=x, [bp+10]=y, [bp+8]=number, [bp+6]=digits, [bp+4]=colour | Out: number drawn | Changes: none
draw_number:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si

    mov ax, [bp+8]
    mov cx, [bp+6]
    mov bx, 10
.div_lp:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    dec cx
    jz $+5
    jmp near .div_lp

    mov si, [bp+12]
    mov cx, [bp+6]
.pop_lp:
    pop dx
    push si
    push word [bp+10]
    push word [bp+4]
    push dx
    call draw_char
    add si, 8
    dec cx
    jz $+5
    jmp near .pop_lp

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; Prints 32-bit score (score_high:score_low) as 6 zero-padded digits
; Inputs: [bp+6]=x, [bp+4]=y

; draw_score_6digits - Draw the 32-bit score as 6 digits
;   In: [bp+6]=x, [bp+4]=y | Out: score drawn | Changes: none
draw_score_6digits:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si

    ; Divide 32-bit score by 1000 to split into upper 3 and lower 3 digits
    mov dx, [score_high]
    mov ax, [score_low]
    mov bx, 1000
    div bx                          ; AX = upper 3 digits, DX = lower 3 digits

    push dx
    push word [bp+6]
    push word [bp+4]
    push ax
    push word 3
    push word COL_WHITE
    call draw_number

    pop dx
    mov ax, [bp+6]
    add ax, 24
    push ax
    push word [bp+4]
    push dx
    push word 3
    push word COL_WHITE
    call draw_number

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

; draw_hud - Draw the HUD strip: score, coins, world, time, lives, hearts
;   In: none | Out: HUD drawn | Changes: none
draw_hud:
    push ax
    push bx

    ; Dark Blue (0xFF0D47A1) HUD bar across row 0 (top 16 pixels)
    push word 0
    push word 0
    push word 320
    push word 16
    push word COL_HUD
    call fill_rect

    push word 8
    push word 0
    push word COL_YELLOW
    push word str_hud_top
    call draw_string

    ; 6-digit Score
    push word 8
    push word 8
    call draw_score_6digits

    ; 2-digit Coins
    mov al, [coins]
    xor ah, ah
    push word 72
    push word 8
    push ax
    push word 2
    push word COL_WHITE
    call draw_number

    ; World 1-1
    push word 112
    push word 8
    push word COL_WHITE
    push word str_world
    call draw_string

    ; 3-digit Clock
    push word 160
    push word 8
    push word [game_clock]
    push word 3
    push word COL_WHITE
    call draw_number

    ; 2-digit Lives
    mov al, [lives]
    xor ah, ah
    push word 208
    push word 8
    push ax
    push word 2
    push word COL_WHITE
    call draw_number

    ; Health Hearts (2 icons)
    push word 264
    push word 9
    push word 6
    push word 6
    push word COL_RED
    call fill_rect

    mov al, COL_GRAY
    cmp byte [mario_hp], 2
    je $+5
    jmp near .h2
    mov al, COL_RED
.h2:
    push word 274
    push word 9
    push word 6
    push word 6
    xor ah, ah
    push ax
    call fill_rect

    pop bx
    pop ax
    ret


; COMPOSITE GAMEPLAY FRAME RENDERER & RESET ROUTINES (Modules 14 & 15)

; render_gameplay_frame - Draw the whole gameplay picture into the buffer
;   In: none | Out: buffer holds the frame | Changes: none
render_gameplay_frame:
    push ax
    push bx
    push cx
    push dx
    push si

    push word COL_SKY
    call clear_buffer

    call draw_visible_map

    ; Draw Mushroom if active
    cmp byte [mush_active], 1
    je $+5
    jmp near .draw_enemies
    mov ax, [mush_x]
    sub ax, [camera_x]
    push ax
    push word [mush_y]
    push word spr_mushroom
    push word 0
    call draw_sprite

.draw_enemies:
    mov si, enemy_table
    mov cx, MAX_ENEMIES
.en_lp:
    mov al, [si+1]
    cmp al, 0
    jne $+5
    jmp near .nxt_en
    mov ax, [si+2]
    sub ax, [camera_x]
    cmp ax, -16
    jg $+5
    jmp near .nxt_en
    cmp ax, 320
    jl $+5
    jmp near .nxt_en

    mov bx, spr_goomba
    cmp byte [si+0], 1
    je $+5
    jmp near .koopa_spr
    cmp byte [si+1], 3
    je $+5
    jmp near .do_en_spr
    mov bx, spr_goomba_flat
    jmp near .do_en_spr
.koopa_spr:
    mov bx, spr_koopa
    cmp byte [si+1], 3
    jae $+5
    jmp near .do_en_spr
    mov bx, spr_shell
.do_en_spr:
    push ax
    push word [si+4]
    push bx
    xor dx, dx
    mov dl, [si+7]
    push dx
    call draw_sprite
.nxt_en:
    add si, 12
    dec cx
    jz $+5
    jmp near .en_lp

    ; Draw Baby Peach (skip every alternate frame if invulnerable blinking)
    cmp word [mario_invuln], 0
    jne $+5
    jmp near .draw_mario_now
    test word [frame_counter], 1
    jz $+5
    jmp near .draw_hud_now

.draw_mario_now:
    mov bx, spr_peach_jump          ; pick the pose: jump, run or stand
    cmp byte [mario_on_ground], 1
    je $+5
    jmp near .pose_done
    mov bx, spr_baby_peach
    cmp word [mario_vx], 0
    jne $+5
    jmp near .pose_done
    mov bx, spr_peach_run1
    test word [frame_counter], 4
    jnz $+5
    jmp near .pose_done
    mov bx, spr_peach_run2
.pose_done:
    mov ax, [mario_x]
    sub ax, [camera_x]
    xor dx, dx
    mov dl, [mario_dir]
    cmp byte [mario_hp], 2
    je $+5
    jmp near .small_spr
    or dx, 2                        ; Super Baby Peach: stretch to 16x32
.small_spr:
    push ax
    push word [mario_y]
    push bx
    push dx
    call draw_sprite

.draw_hud_now:
    call draw_hud

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Resets level after losing a life (keeps Score, Coins, Lives - Section 5.8)

; reset_level_life - Restart the level after a lost life (score, coins, lives kept)
;   In: none | Out: level variables reset | Changes: none
reset_level_life:
    call reset_map
    call spawn_enemies
    mov word [mario_x], 32
    mov byte [mario_x_sub], 0
    mov word [mario_y], 144
    mov byte [mario_y_sub], 0
    mov word [mario_vx], 0
    mov word [mario_vy], 0
    mov byte [mario_dir], 0
    mov byte [mario_on_ground], 1
    mov byte [mario_hp], 1
    mov word [mario_invuln], 0
    mov word [stomp_chain], 0
    mov word [camera_x], 0
    mov word [game_clock], 300
    mov word [sec_ticks], 0
    mov byte [mush_active], 0
    ret

; Resets everything for a brand new game (Section 5.8)

; reset_new_game - Reset everything for a brand new game
;   In: none | Out: all game variables reset | Changes: none
reset_new_game:
    mov word [score_low], 0
    mov word [score_high], 0
    mov byte [coins], 0
    mov byte [lives], 3
    call reset_level_life
    ret
