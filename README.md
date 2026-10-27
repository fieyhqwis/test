# blockpvp

Обфусцированный билд чита + конфиг релея.

## Что здесь

| файл | что |
|---|---|
| `blockpvp_ka.obf.luau` | сам скрипт, его тянет загрузчик |
| `config.json` | адрес Cloudflare-воркера, меняется без пересборки |
| `loader.lua` | что вставлять в экзекьютор |

## Загрузчик

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/blockpvp_ka.obf.luau"))()
```

## Сменить вебхук

1. Cloudflare → Workers & Pages → `blockpvp-relay` → Settings → Variables and Secrets → `HOOK` → Edit → Save & Deploy.
2. Всё. Скрипт, загрузчик и репозиторий не трогаются.

## Сменить адрес воркера

Правь `config.json` прямо на гитхабе. Подхватится при следующем запуске чита.
