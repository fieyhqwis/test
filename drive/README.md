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

The thrust values live in `ReplicatedStorage.Shared.Config.AbilityConfig.Nitro`
(the car controller reads `AbilityConfig.Nitro` every frame, not its own copy).

```
GroundThrust   0.45  -> 0.675   (x1.5)
AirThrust      1.30  -> 1.95
TopSpeedAdd    20    -> 30
AirThrustMax   110   -> 165
EngineScale    1.45  -> 1.8125
```

At x3: ground 1.35, air 3.90, top +60, engine 2.9. That is where the car starts
flipping on landings.

## Notes

- works only while a car exists; the status label says "waiting for car" otherwise
- unload clears the toggle and stops the loop
