# Шаблон меню BSSS

## Обзор

`lib/menu_template.sh` содержит стандартизированный паттерн для создания интерактивных меню в модулях BSSS.

## Архитектура

Паттерн: **Source → Sink (display) → Filter (select) → Orchestrator (dispatch)**

```
get_items() ──→ display() ──→ get_user_choice() ──→ dispatch_menu()
   |              |                 |                    |
   |              |                 v                    v
   |              |            id\0                execute action
   |              v
   id|text\0
```

## Ключевые функции

### Source
- `domain::menu::get_items()` - Генерирует пункты меню в формате `id|text\0`
- `domain::menu::count_items()` - Подсчитывает количество пунктов

### Sink
- `domain::menu::display()` - Отображает меню пользователю (вывод в stderr)

### Filter
- `domain::menu::get_user_choice()` - Запрашивает выбор пользователя

### Orchestrator
- `domain::orchestrator::dispatch_menu(menu_id)` - Выполняет выбранное действие
- `domain::menu::run()` - Полный цикл работы меню

## Быстрый старт

### 1. Создайте базовую структуру меню

```bash
# Скопируйте функции в ваш модуль
domain::menu::get_items() {
    printf '%s|%s\0' "1" "Действие 1"
    printf '%s|%s\0' "2" "Действие 2"
    printf '%s|%s\0' "0" "Выход"
}

domain::menu::display() {
    local id text
    log_info "$(_ "common.menu_header")"
    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(domain::menu::get_items)
}

domain::menu::get_user_choice() {
    local qty_items=$(($(domain::menu::count_items) - 1))
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"
    io::ask_value "$(_ "domain.menu.select_prompt")" "" "$pattern" "$hint" "0"
}
```

### 2. Реализуйте диспетчеризацию

```bash
domain::orchestrator::dispatch_menu() {
    local menu_id="$1"

    case "$menu_id" in
        1) domain::action_one ;;
        2) domain::action_two ;;
        *)
            log_error "$(_ "domain.error.invalid_menu_id" "$menu_id")")
            return 1
            ;;
    esac
}
```

**ВАЖНО**:
- Нет явных `return` - код возврата пробрасывается автоматически из последней команды
- `io::ask_value` сама возвращает код 2 при выборе cancel_keyword (пункт 0)
- `dispatch_menu` никогда не получит `menu_id == 0` (это обрабатывается `io::ask_value`)

### 3. Интегрируйте в модуль

```bash
# Полный цикл
domain::menu::run

# Или раздельно
domain::menu::display
local menu_id
menu_id=$(domain::menu::get_user_choice | tr -d '\0')
domain::orchestrator::dispatch_menu "$menu_id"
```

## Продвинутые возможности

### Динамическое меню на основе состояния

```bash
ufw::menu::get_items() {
    ufw::status::is_active && \
        printf '%s|%s\0' "1" "Отключить UFW" || \
        printf '%s|%s\0' "1" "Включить UFW"
    ufw::ping::is_configured && \
        printf '%s|%s\0' "2" "Разрешить пинг" || \
        printf '%s|%s\0' "2" "Запретить пинг"
    printf '%s|%s\0' "0" "Выход"
}
```

### Условное отображение статусов

```bash
permissions::menu::display() {
    # Показываем контекст перед меню
    permissions::orchestrator::log_statuses
    
    log_info "$(_ "common.menu_header")"
    # ... стандартный цикл отображения ...
}
```

## Примеры реализации

| Модуль | Файл | Описание |
|--------|------|----------|
| UFW | `modules/helpers/ufw.sh` | Полный пример динамического меню |
| Permissions | `modules/helpers/permissions.sh` | Пример с логированием статусов |
| SSH | `modules/ssh-port-modify.sh` | Рефакторинг из статического меню |

## Контракты функций

### get_items()
- **Input**: Нет
- **Output**: `id|text\0` (NUL-separated)
- **Exit code**: 0
- **ID**: Должны быть числами для упрощения валидации

### display()
- **Input**: Нет
- **Output**: Нет (только stderr)
- **Exit code**: 0

### get_user_choice()
- **Input**: Нет
- **Output**: `id\0`
- **Exit code**: 0 (выбор), 2 (отмена/пункт 0)
- **ПРИМЕЧАНИЕ**: Возвращает код 2 если пользователь ввел cancel_keyword

### dispatch_menu()
- **Input**: `menu_id` (число)
- **Output**: Нет
- **Exit code**: 0 (успех), $? (ошибка действия, автоматический проброс)
- **ПРИМЕЧАНИЕ**: Никогда не получит `menu_id == 0` - это обрабатывает `io::ask_value`

## Переводы

Добавьте в `lib/i18n/ru/domain.sh` и `lib/i18n/en/domain.sh`:

```bash
# Domain menu
I18N_MESSAGES["domain.menu.select_prompt"]="Выберите действие"
I18N_MESSAGES["domain.error.invalid_menu_id"]="Неверный выбор: %s"
I18N_MESSAGES["domain.menu.item_action1"]="Действие 1"
I18N_MESSAGES["domain.menu.item_action2"]="Действие 2"
```

## Важно

### Порядок выполнения

**ВАЖНО**: `get_user_choice()` и `dispatch_menu()` должны запускаться в одном процессе:

```bash
# ПРАВИЛЬНО
menu_id=$(domain::menu::get_user_choice | tr -d '\0')
domain::orchestrator::dispatch_menu "$menu_id"

# НЕПРАВИЛЬНО (для критических действий с сигналами)
domain::menu::get_user_choice | domain::orchestrator::dispatch_menu
```

Причина: Сигналы (например, SIGUSR1 для rollback) должны корректно обрабатываться.

### NUL-разделители

Все потоки данных используют `\0` как разделитель:
- `id|text\0` для пунктов меню
- `id\0` для выбора пользователя

### Logging

Все выводы меню должны идти в **stderr** через `log_*` функции:
- `log_info()` - основная информация
- `log_info_simple_tab()` - пункты меню с отступом
- `log_error()` - ошибки

## Исключения

### main.sh и i18n/language_installer.sh

Используют **массивы + NUL** вместо чистого pipe-first подхода.

**Причина**: Сохранение контекста между display() и select().

**Комментарий из main.sh:132**:
> В чистом pipe-first стиле это невозможно без временных файлов или глобальных переменных.
> Для интерактивных меню это технически оправданное исключение.

Эти реализации остаются без изменений.

## Чеклист для новых модулей

- [ ] Создать `domain::menu::get_items()` с пунктами меню
- [ ] Создать `domain::menu::display()` для отображения
- [ ] Создать `domain::menu::get_user_choice()` для выбора
- [ ] Создать `domain::orchestrator::dispatch_menu()` для диспетчеризации
- [ ] Опционально: `domain::menu::count_items()` если нужен
- [ ] Добавить переводы в `lib/i18n/ru/domain.sh`
- [ ] Интегрировать в модуль через `domain::menu::run` или раздельно
- [ ] Проверить обработку сигналов если используется rollback

## Рефакторинг существующего модуля (SSH пример)

### Было:

```bash
ssh::menu::display_exists_scenario() {
    log_info "1. Сброс"
    log_info "2. Переустановка"
    log_info "0. Выход"
}

choice=$(io::ask_value ... "^[012]$" "0-2" "0")
case "$choice" in
    1) ssh::reset::port ;;
    2) ssh::install::port ;;
esac
```

### Стало:

```bash
ssh::menu::get_items() {
    printf '%s|%s\0' "1" "Сброс"
    printf '%s|%s\0' "2" "Переустановка"
    printf '%s|%s\0' "0" "Выход"
}

ssh::menu::display() {
    # стандартная реализация
}

ssh::menu::get_user_choice() {
    # стандартная реализация
}

ssh::orchestrator::dispatch_menu() {
    local menu_id="$1"
    case "$menu_id" in
        1) ssh::reset::port ;;
        2) ssh::install::port ;;
        *)
            log_error "$(_ "ssh.error_invalid_choice" "$menu_id")"
            return 1
            ;;
    esac
}

ssh::orchestrator::config_exists_handler() {
    ssh::menu::display
    local menu_id
    menu_id=$(ssh::menu::get_user_choice | tr -d '\0')
    ssh::orchestrator::dispatch_menu "$menu_id"
}
```

## Связанная документация

- `AGENTS.md` - Архитектурные принципы проекта
- `function_map.txt` - Карта функций
- `lib/i18n/README.md` - Система переводов

## Поддержка

Для вопросов по использованию шаблона обращайтесь к существующим реализациям:
- `modules/helpers/ufw.sh` - базовый пример
- `modules/helpers/permissions.sh` - расширенный пример
- `modules/ssh-port-modify.sh` - рефакторинг из старого стиля
