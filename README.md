# Pi bootstrap

Шаблон саморазвёртывающейся конфигурации [pi](https://pi.dev) для любого проекта: настройки, универсальные skills и стандартные npm-пакеты.

Склонируйте репозиторий в папку `pi/` в **корне целевого проекта**, запустите `install.sh` — скрипт превратит `pi/` в `.pi/` и удалит себя. В итоге в проекте появляется готовая среда для AI-агента pi с выбором только нужных компонентов.

## Что это даёт

| Компонент | Назначение |
|-----------|------------|
| `.pi/settings.json` | Настройки pi: пакеты, compaction, retry |
| `.pi/SYSTEM.md` | Системный промпт агента для проекта |
| `.pi/skills/` | Универсальные skills (минимальные диффы, monorepo, чеклисты и т.д.) |
| npm-пакеты pi | Workflows, Cursor SDK, субагенты, MCP (по выбору) |
| Understory | Долговременная память агента через Docker + MCP (по выбору) |

## Требования

- bash
- Node.js + npm (для pi CLI и пакетов)
- git (чтобы клонировать этот репозиторий)
- Docker — только если выбираете Understory (скрипт может установить через [get.docker.com](https://get.docker.com/))

## Установка

Запускайте **из корня целевого проекта**, не из уже существующей `.pi/`:

```bash
git clone <url-этого-репозитория> pi
./pi/install.sh              # интерактивный квиз — выбрать компоненты
./pi/install.sh --yes          # установить всё без вопросов
```

Без git (копирование вручную):

```bash
cp -a /path/to/pi-bootstrap /path/to/project/pi
cd /path/to/project && ./pi/install.sh
```

Переменная окружения `PI_INSTALL_YES=1` эквивалентна флагу `--yes`.

### Квиз: что можно выбрать

Базовая конфигурация `.pi/` (settings, skills, SYSTEM.md) устанавливается **всегда**. Остальное — на ваш выбор:

| # | Компонент | Описание |
|---|-----------|----------|
| 1 | **Pi CLI** | Глобальная установка через npm, если ещё нет |
| 2 | **pi-extensible-workflows** | Оркестрация workflow |
| 3 | **pi-cursor-sdk** | Мост к Cursor IDE |
| 4 | **pi-subagents** | Делегирование субагентам |
| 5 | **pi-mcp-adapter** | MCP-инструменты |
| 6 | **Understory** | Docker + память агента + `docker-compose.und.yml` |

После ответов скрипт показывает итог и спрашивает «Продолжить установку?».

Без TTY (pipe, CI) — все пункты по умолчанию «да».

### Что делает скрипт

1. Сохраняет ваш выбор и устанавливает pi CLI (если выбрано)
2. Переименовывает `pi/` → `.pi/`, удаляет bootstrap-`.git`
3. Обрезает `settings.json` — только выбранные npm-пакеты
4. Ставит пакеты через `pi install -l` (только выбранные)
5. При отказе от Understory — удаляет skill, compose и example env из шаблона
6. При выборе Understory — Docker, clone, compose в корень проекта
7. Генерирует `AGENTS.md` в корне проекта (сканер стека + команды + pi skills)
8. Удаляет `install.sh` после успешного завершения

## После установки

```bash
cd /path/to/your-project
pi
# в сессии pi: /trust
```

Настройка под проект:

- `.pi/SYSTEM.md` — системный промпт
- `.pi/skills/` — project-specific skills
- `AGENTS.md` в корне — автогенерируется при установке (не перезаписывает существующий)
- Перегенерация: `PI_AGENTS_FORCE=1 bash .pi/scripts/generate-agents-md.sh "$PWD" .pi`

Skills подключаются в pi: `/skill:<имя>`.

## Встроенные skills

| Skill | Назначение |
|-------|------------|
| `minimal-diff` | Минимальные, сфокусированные изменения кода |
| `monorepo-map` | Разведка структуры репозитория |
| `pre-push-checklist` | Проверки перед commit/PR |
| `env-and-docker` | Compose и env-файлы |
| `pi-feature-workflow` | Кросс-слойная работа нескольких агентов |
| `understory` | Память агента через MCP + Docker (если выбран при установке) |

## Understory (память агента)

Если выбран при установке, скрипт:

1. Ставит Docker (через get.docker.com), если его нет
2. Клонирует [mitagmio/understory](https://github.com/mitagmio/understory) в `.pi/understory/`
3. Копирует `docker-compose.und.yml` в **корень проекта**
4. Создаёт `.env.understory` из примера
5. Запускает `docker compose -f docker-compose.und.yml up -d --build`

Память: `.pi/understory-memory/` · Web UI: http://localhost:3800 · MCP: http://localhost:3800/mcp

Заполните в `.env.understory`: `LLM_API_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`. Затем:

```bash
docker compose -f docker-compose.und.yml --env-file .env.understory up -d --build
```

## npm-пакеты

Список в `.pi/settings.json` (после установки — только выбранные):

- `pi-extensible-workflows` — оркестрация workflow
- `pi-cursor-sdk` — мост Cursor IDE
- `pi-subagents` — субагенты
- `pi-mcp-adapter` — MCP

Переустановка или обновление:

```bash
pi install -l npm:pi-extensible-workflows --approve
pi update --extensions -l --approve
```

## Обновление шаблона

Редактируйте файлы в этом репозитории, коммитьте и заново клонируйте или копируйте в проекты, которым нужна новая база. Уже установленные проекты сохраняют локальную `.pi/` до ручного merge изменений.

## Важно

- Запускайте `./pi/install.sh` только из **корня проекта**, куда клонировали `pi/`. Не запускайте из родительской папки — скрипт переименует `pi/` в `.pi/` относительно родителя.
- Секреты (`.env.understory` с ключами API) не коммитьте — при установке Understory скрипт добавляет их в `.gitignore` проекта.
