# Protocol reference — AULA F108 Pro

This is a condensed implementation reference. The authoritative, hardware-verified
sources are linked at the bottom. Payload offsets are into the 64-byte feature
report (no report-ID byte on the wire).

## Device

| Mode | VID:PID | Product | Config interface |
|---|---|---|---|
| USB-C wired | `0C45:800A` | `AULA F108Pro` | interface 3, usage page `0xFF13`, 64-byte Feature |
| 2.4 GHz dongle | `05AC:024F` | `F108Pro Dongle` | interface 3, usage page `0xFF60`, 33-byte in/out |
| Bluetooth | `05AC:024F` (Apple IDs) | `AULA-F108Pro-N` | **no vendor collection** |

Wired LCD interface: interface 2, usage page `0xFF68`, 4096-byte output reports.

All configuration commands use 64-byte feature reports, report ID 0, with ~35 ms
between commands. `04 xx` steps require a GET_FEATURE readback; the ACK is
`byte[3] == 0x01`. Data tables end with a two-byte marker; the byte order varies
by command family (`55 AA` for lighting/clock, `AA 55` for remap/macros/options).

## Sequences

```text
lighting:  04 18 RB → 04 13 (b8=01) RB → data → 04 02 RB → 04 F0
per-key:   04 18 RB → 04 13 RB → 80 .. (b9=brightness) → 04 02 RB → 04 F0
           04 18 RB → 04 23 (b8=09 RGB / 03 mono) RB → 576 B → 04 02 RB → 04 F0 RB
remap:     04 18 RB → 04 11 (normal) / 04 27 (FN) (b8=09) RB → 576 B → 04 02 RB → 04 F0 RB
macros:    04 19 RB → 04 15 (b8=report count) RB → buffer → 04 02 RB
options:   04 18 RB → 04 17 (b2=01,b8=01) RB → data (no RB) → 04 02 RB
clock:     04 18 RB → 04 28 (b8=01) RB → data RB → 04 02 RB
```

## Lighting

Data packet:

| Offset | Field | Values |
|---|---|---|
| 0 | mode | 0 off, 1 static … 19 shuttle |
| 1–3 | R,G,B | 0–255 |
| 8 | colorful | 0 single, 1 rainbow |
| 9 | brightness | 0–5 |
| 10 | speed | 0–5 |
| 11 | direction | 0/1 |
| 14–15 | trailer | `55 AA` |

Mode IDs: 0 Off, 1 Static, 2 SingleOn, 3 SingleOff, 4 Glittering, 5 Falling,
6 Colourful, 7 Breath, 8 Spectrum, 9 Outward, 10 Scrolling, 11 Rolling,
12 Rotating, 13 Explode, 14 Launch, 15 Ripples, 16 Flowing, 17 Pulsating,
18 Tilt, 19 Shuttle.

Per-key RGB: a 576-byte buffer with 4-byte slots at `light_index * 4`
(`[index, R, G, B]`). Valid light indices 1…123; 0 is unused. Missing slots are
dark. Trailer `55 AA` at bytes 574–575. The preamble data packet is
`byte[0]=0x80, byte[9]=brightness, bytes[14..15]=55 AA`.

## Remap

576 bytes, 4-byte slot at `key_index * 4`, trailer `AA 55` at 574–575.
A zero slot keeps factory behavior. Source key indices come from the vendor
`rgb-keyboard.xml` (also used as light indices on this board).

| Action | Bytes |
|---|---|
| none | `00 00 00 00` |
| key / shortcut | `02 mods hid 00` |
| modifier only | `02 bit 00 00` |
| consumer | `03 lo hi 00` |
| special | `01 a b 00` |
| macro | `06 slot mode count` |
| mouse | `07 a b c 00` |
| disabled | `05 03 00 00` |

Modifier bits: L-Ctrl `01`, L-Shift `02`, L-Alt `04`, L-Win/Cmd `08`,
R-Ctrl `10`, R-Shift `20`, R-Alt `40`, R-Win/Cmd `80`.

## Macros

Buffer (max 0xE00 bytes):

- 400-byte header: 100 × LE16 data offsets; empty slot = `FF FF FF FF`.
- Data blocks at those offsets: LE16 event count, 6 zero bytes, then 4-byte events.
- Event: `[delay_lo, delay_hi, code, flag]`
  - key down `B0`, key up `30`; code is a HID usage
  - mouse down `90`, up `10`; code is left `01`, right `04`, middle `02`
  - delay `50`, code unused, LE16 milliseconds (minimum 10)
- Padded to 64-byte reports, trailer `AA 55`.

A remap slot with action `06` executes macro `slot` (0-based). Modes: 0 once,
1 repeat `count` times, 2 toggle, 3 while held.

## Options

Data packet:

```text
00 01 noAltTab noAltF4 noWin fnToggle sleep 00 response … AA 55 @ 62
```

- sleep: 0 never, 1 one minute, 2 five minutes, 3 thirty minutes
- response: debounce level 1…5
- fnToggle: 0 while held, 1 tap to toggle

## Clock

```text
00 01 5A (year % 2000) month day hour minute second 00 weekday … 55 AA @ 62
```

weekday: 0 Sunday … 6 Saturday. No finalize step for clock sync.

## Key indices

The 104 physical keys use the vendor's `key_index` values (gaps are normal):
1–13 Esc/F1–F12; 19–31 `` ` ``/1…0/-/=; 32–34 and 122 numpad top; 37–49 QWERTY
row; 50–52 numpad 7/8/9; 55–66 home row; 67 backslash; 68–70 numpad 4/5/6; 73–84
shift row; 85 Enter; 86–88 numpad 1/2/3; 91–98 bottom modifiers/Fn/Menu;
99–102 arrows; 103 Backspace; 104–106 numpad 0/./Enter; 112–123 Print/Scroll/
Pause/Insert/Home/PgUp/Delete/End/PgDn/num-/.

## Sources

- <https://github.com/parsiya/f108-pro> (MIT) — lighting, remap, macros, clock, LCD
- <https://github.com/bacoinz/aula-studio/blob/main/docs/protocol.md> — options, macros, dongle
- <https://github.com/sarequl/aula-studio> (MIT) — macOS IOKit implementation
- <https://github.com/AuRoN89/AULA-F108-PRO-Reverse-Engineering> — hardware teardown
- <https://gitlab.com/CalcProgrammer1/OpenRGB/-/issues/5253> — VID/PID and interface reports
