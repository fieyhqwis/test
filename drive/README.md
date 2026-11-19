# DRIVE ONLY UP — infinite nitro

Place: `116517168170959`

**Script:** `nitro.luau`

Menu key: **RightShift**

## What it does

Pins the car nitro tank at full, so boost never runs out.

## How

The car logic lives in `PlayerScripts.Client.Controllers.CarController` (Knit controller).

```
car.nitro           — current nitro
car._nitroCfgTank   — tank size
```

The script sets `car.nitro = car._nitroCfgTank` every 0.1s.

## Verified

```
car found        = true
tank             = 1.00
nitro samples    = 1.00 1.00 1.00 1.00 1.00 1.00 1.00 1.00
```

## Menu

```
Nitro
├ Infinite nitro     (toggle + bind, bind empty)
├ Nitro power x      (1.00 .. 3.00, default 1.3)
└ status: nitro / tank
```

## Nitro power

Multiplies the car's own nitro parameters:

```
GroundThrust   0.45 -> 0.585  (x1.3)
AirThrust      1.30 -> 1.69
TopSpeedAdd    20   -> 26
AirThrustMax   110  -> 143
```

At x2: ground 0.90, air 2.60, top +40. Above x2.5 the car starts flipping on landings.

## Notes

- works only while a car exists; the status label says "waiting for car" otherwise
- unload clears the toggle and stops the loop
