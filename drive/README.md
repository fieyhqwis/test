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
├ Infinite nitro   (toggle + bind, bind empty)
└ status: nitro / tank
```

## Notes

- works only while a car exists; the status label says "waiting for car" otherwise
- unload clears the toggle and stops the loop
