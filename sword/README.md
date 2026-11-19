# RAGDOLL SWORD BATTLES — mouse sensitivity

Place: `98357644168592`

**Script:** `sensitivity.luau`

Menu key: **RightShift**

## What it does

Changes the camera mouse sensitivity, which the game does not expose in its own settings.

## How

`UserInputService.MouseDeltaSensitivity` is a global multiplier the camera reads every frame.

```
game default = 1.00
script value = slider (0.20 .. 5.00)
```

Applied instantly and re-applied every 0.35s in case something resets it. On unload it is restored to the value the game had before the script ran.

## Verified

```
window = true
sens state = 1.60
MouseDeltaSensitivity = 1.60
```

## Menu

```
Mouse
├ Mouse sensitivity   0.20 .. 5.00 (1.60)
├ Reset to game default (1.0)
└ status: current / default
```

## Notes

- the fallback cursor is drawn while the menu is open, because the game hides the system cursor
- settings saved to `RAT4080/SwordBattles/config.json`
