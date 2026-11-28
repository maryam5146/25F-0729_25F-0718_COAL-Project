# Baby Peach Engine

EL2003 Computer Organization and Assembly Language, Fall 2026
FAST-NUCES

A 16-bit side-scrolling platform game written in x86 assembly (NASM), running in DOSBox. VGA Mode 13h, real mode, single-segment `.COM` program (`MARIO.COM`). The hero is Baby Peach instead of Mario (see Deviations).



---

## 1. Team

| Name | Roll Number |
|------|-------------|
| Muhammad Rehan Akas | 25F-0718 |
| Maryam Salman | 25F-0729 |

- Section: [3F]
- Lab instructor: [Choudhary Shehzad Tanveer]


---

## 2. Repository Layout

```
COAL_Project_[3F]_25F-0718_25F-0729/
  MARIO.asm     source code (single file)
  MARIO.COM     assembled executable
  README.md
 
---

## 3. Build and Run

### Requirements

- NASM
- DOSBox v0.74-3 or later

### Build

```
nasm MARIO.asm -f bin -O0 -o MARIO.COM
```

The source uses `cpu 386` and `[org 0x0100]`. No optimisation flag is needed.

### Run in DOSBox

```
mount c C:\path\to\project
c:
MARIO
```

 Replace the path and confirm the commands work from a clean DOSBox session.

---

## 4. Controls

| Key | Scan code | Action |
|-----|-----------|--------|
| Left arrow | 4Bh | Move left |
| Right arrow | 4Dh | Move right |
| Up / Down arrow | 48h / 50h | Move menu highlight |
| Space | 39h | Jump (hold for higher jump, no double jump) |
| Left Shift | 2Ah | Run |
| P | 19h | Pause / resume |
| Enter | 1Ch | Select in menus, continue on end screens |
| Esc | 01h | Back to title / exit from title |

### Debug keys

Active only in the PLAYING state.

| Key | Scan code | Effect |
|-----|-----------|--------|
| T | 14h | Sets the clock to 5 seconds |
| C | 2Eh | Sets coins to 99 (the next coin gives an extra life) |

---

## 5. Memory Choices

- **Program model:** `.COM`, one segment for code, data and stack, entry at `ORG 100h`.
- **Frame buffer:** a full 64,000-byte buffer in the next 64 KB segment above the program. At start, `buf_seg` is set to `CS + 1000h` and all drawing goes into that segment. No DOS memory allocation call is used. The buffer is cleared with `REP STOSW` (32000 words) and copied to `A000h` with `REP MOVSW` once per frame.
- **Level maps:** two 720-byte maps (60 columns x 12 rows, one byte per tile): `original_map` is never changed, `working_map` is modified by gameplay. `reset_map` restores it with one `REP MOVSB`.
- **Enemy table:** 8 records of 12 bytes. Layout: type (+0), state (+1), world x word (+2), world y word (+4), x sub-pixel (+6), direction (+7), timer word (+8). States: 0 removed, 1 idle, 2 walking, 3 flattened Goomba or stationary shell, 4 sliding shell. Enemies are filled from `enemy_spawns` by `spawn_enemies`.
- **Keyboard tables:** `key_state` (128 bytes, 1 = held) and `key_edge` (128 bytes, 1 = newly pressed). `key_edge` is cleared on every state change so old presses do not leak into the next screen.
- **Fixed point:** position and velocity are 8.8. The whole-pixel part is used for drawing and the camera.
- **Parameters:** procedures take their inputs on the stack and clean them with `ret n`. Registers that are not returned are saved and restored.
- **Interrupts:** INT 09h (keyboard) and INT 08h (timer) are saved with INT 21h AH=35h and replaced with AH=25h. The timer handler increments `tick_count` and chains to the old handler. PIT channel 0 is set to 30 Hz (divisor 39773). On exit, `unhook_interrupts` restores the PIT to 18.2 Hz and both vectors, then returns to text mode and DOS.
- **Text:** drawn from the 8x8 ROM BIOS font at `F000:FA6E`.

---

## 6. Game States

The game runs on `game_state` and a jump table (`state_jump_table`).

| State | Entered when | Left when |
|-------|--------------|-----------|
| TITLE | Program start; after Game Over; after Level Complete | Enter on START goes to PLAYING. Enter on EXIT or Esc goes to EXIT |
| PLAYING | New game; after the Life-lost screen | P goes to PAUSED. Death goes to DYING. Flag reached goes to WIN SEQUENCE. Esc goes to TITLE |
| PAUSED | P pressed while playing | P goes to PLAYING. Esc goes to TITLE. Updates and clock frozen, picture stays with a PAUSED box |
| DYING | HP reaches 0, pit, or clock at 0 | After about 1.5 s: LIFE LOST if lives remain, otherwise GAME OVER |
| LIFE LOST | After the death animation | After about 2 s, the level is reset and the game goes to PLAYING |
| WIN SEQUENCE | Flag reached | After the slide and walk, time x 50 is added and the game goes to LEVEL COMPLETE |
| LEVEL COMPLETE | After the win sequence | Enter goes to TITLE |
| GAME OVER | Last life lost | Enter goes to TITLE |
| EXIT | Exit chosen from title, or Esc at title | Vectors and timer restored, text mode, DOS |

Each frame in PLAYING follows the manual's order: read keys, update Baby Peach, update mushroom and enemies, resolve collisions, count invulnerability and the clock, check death and flag, update camera, draw into the buffer, copy to the screen.

---

## 7. Modules

| # | Module | Main procedures |
|---|--------|-----------------|
| 1 | Program skeleton and constants | `main_entry`, `state_exit_fn`, EQU constants | 
| 2 | Video mode and colours | `init_video_mode13h`, `setup_custom_palette`, `put_pixel`, `fill_rect` | 
| 3 | Level map and tiles | `reset_map`, `get_tile`, `is_tile_solid`, `draw_tile`, `draw_visible_map` | 
| 4 | Sprites | `draw_sprite` (mirror and 16x32 stretch flags, clipped through `put_pixel`) |
| 5 | Frame buffer | `clear_buffer`, `flip_buffer` | 
| 6 | Camera and scrolling | `update_camera` | 
| 7 | Keyboard handler | `kb_isr`, `hook_interrupts`, `unhook_interrupts` | 
| 8 | Timer and clock | `timer_isr`, 30 Hz PIT setup, clock from `tick_delta` | 
| 9 | Movement and physics | `update_mario_physics` | 
| 10 | Collision detection | tile checks in `update_mario_physics`, `check_entity_collisions` | 
| 11 | Enemies and shells | `spawn_enemies`, `update_enemies`, `check_enemy_bump`, `check_shell_vs_enemies`, `award_stomp_chain` | 
| 12 | Blocks, coins, mushroom | `trigger_block_hit`, `collect_coin`, `update_mushroom` | 
| 13 | Score, HUD | `add_score` (ADD/ADC), `draw_char`, `draw_string`, `draw_number`, `draw_score_6digits`, `draw_hud` | 
| 14 | States and screens | `state_*_fn` handlers, `render_gameplay_frame` | 
| 15 | Win, lose, restart, exit | `trigger_flag_win`, `reset_level_life`, `reset_new_game`, `state_exit_fn` | 

---

## 8. Deviations from the Manual

| Deviation | Reason |
|-----------|--------|
| Hero is Baby Peach with a pink theme instead of Mario. Coins are star-shaped. Custom palette colours (indices 200 to 205) are programmed through the VGA DAC, and the sky colour is changed. | Original artwork and team theme |
| Physics and speed constants are tuned: walk acceleration 0x0060, friction 0x0030, max walk 0x0280, max run 0x0400, Goomba 0x00A0, Koopa 0x00E0, shell 0x0380, mushroom 0x0140. | Faster, more responsive feel. **[FILL IN]** confirm the Section 5.2 checks still pass |
| Super form is drawn by stretching the 16x16 sprite to 16x32 (draw flag bit 1). | Saves sprite memory |
| Health hearts are drawn as small filled squares, not heart bitmaps. | Simpler HUD |
| The flag is triggered when Baby Peach's world x reaches 888 or more, not by overlapping the flag tile. | Simpler win check |
| Frame buffer is placed at `CS + 1000h` without a DOS allocation call. | Simpler setup |
| Timer is reprogrammed to 30 Hz and restored to 18.2 Hz on exit. | Fixed frame rate |


---

## 9. Bonus Features

- Walking animation (two running poses alternate with the frame counter, plus standing and jumping poses).


---

## 10. References

- NASM documentation (nasm.us)
- Ralf Brown's Interrupt List
- Intel 8086/8088 family user's manual
- DOSBox documentation and debugger guide (dosbox.com)
- Course textbook and lecture slides
