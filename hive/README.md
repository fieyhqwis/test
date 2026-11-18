# INTO THE HIVE — gun cheat

Place: `127112779460977`

**Script:** `gun_cheat.luau`

Menu key: **RightShift**

## What it does

Patches the client copy of `ReplicatedStorage.Shared.Combat.Guns.Types` — the table the
client reads for spread, bloom, recoil and magazine. 32 weapon types.

```
No recoil   -> Recoil.Back 0, Jitter 0, whole spray Pattern zeroed, Kick 0
No spread   -> Spread 0, Aim.Spread 0, Bloom.PerShot 0, Bloom.Max 0
Magazine    -> slider, 0 = leave the real magazine untouched
```

Rapid fire was removed on request — a rate multiplier is the easiest thing to notice.

## Verified

```
patched=32 types
AssaultRifle: spread 0.00, recoil back 0, magazine 30 (untouched)
spread==0 across all 32 types
```

## Menu

```
Guns
├ No recoil      (toggle + bind, bind empty)
├ No spread      (toggle + bind, bind empty)
├ Magazine size  0..300 (0 = real)
└ Re-apply       (if a new weapon type shows up)
```

## Notes

- everything is client side: no packets, no server calls, nothing shows to other players
- magazine stays at the real value by default, because a 300 round mag is the one thing that would look odd
- unloading restores every original value from a snapshot taken before the first patch
- config file `RAT4080/Hive/guns.json` stores only the magazine size, toggles always start on
