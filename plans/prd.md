# PRD: Динамическое меню UFW с потоковой архитектурой

## Версия документа
- Версия: 1.0
- Дата: 2026-01-16
- Автор: Kilo Code
- Статус: Утверждено к разработке

## 1. Обзор

### 1.1 Цель
Разработать динамическое меню управления UFW с использованием потоковой архитектуры (Pipeline-first) и NUL-разделителей, соответствующее философии проекта Bash-инженерия 2026.

### 1.2 Текущее состояние
- Функция `orchestrator::dispatch_logic()` в `modules/05-ufw-modify.sh` использует статическое меню
- Нет проверки текущего состояния UFW
- Нет возможности динамического расширения меню

### 1.3 Требуемая функциональность
1. Динамическое меню на основе текущего состояния UFW
2. Если UFW active → показать "Выключить UFW"
3. Если UFW inactive → показать "Включить UFW"
4. Пункт 0 - выход
5. Расширяемость для будущих функций (управление пингом и др.)

## 2. Архитектура

### 2.1 Потоковая архитектура (Pipeline-first)

```
ufw::get_menu_items | ufw::display_menu
                          ↓ (пользовательский ввод через stdin)
ufw::select_action | ufw::execute_action
```

### 2.2 Типы функций

| Тип | Назначение | Функции |
|-----|------------|---------|
| Source | Генерация данных | `ufw::get_menu_items()` |
| Filter | Трансформация данных | `ufw::display_menu()`, `ufw::select_action()` |
| Orchestrator | Управление логикой | `ufw::execute_action()`, `orchestrator::dispatch_logic()` |
| Sink | Потребление данных | `ufw::toggle()`, `ufw::toggle_ping()` |

### 2.3 Формат данных

#### Пункты меню (Source → Filter)
- Формат: `id|text\0` (NUL-разделитель)
- Пример: `1|Выключить UFW\0`

#### Выбор пользователя (Filter → Orchestrator)
- Формат: `id\0` (NUL-разделитель)
- Пример: `1\0`

## 3. Функциональные требования

### 3.1 Новые функции для `modules/05-ufw-helpers.sh`

#### 3.1.1 `ufw::is_active()`
```bash
# @type:        Filter
# @description: Проверяет, активен ли UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - UFW активен
#               1 - UFW неактивен
```

**Реализация:**
```bash
ufw::is_active() {
    ufw status | grep -q "^Status: active"
}
```

#### 3.1.2 `ufw::get_menu_items()`
```bash
# @type:        Source
# @description: Генерирует список доступных пунктов меню на основе текущего состояния
# @params:      нет
# @stdin:       нет
# @stdout:      id|text\0 (0..N)
# @exit_code:   0 - успешно
```

**Реализация:**
```bash
ufw::get_menu_items() {
    local id=1
    
    # Пункт для переключения UFW
    if ufw::is_active; then
        printf '%s|%s\0' "$id" "Выключить UFW"
    else
        printf '%s|%s\0' "$id" "Включить UFW"
    fi
    id=$((id + 1))
    
    # Резерв для будущих функций (пинг и др.)
    # if ufw::is_ping_blocked; then
    #     printf '%s|%s\0' "$id" "Включить пинг"
    # else
    #     printf '%s|%s\0' "$id" "Отключить пинг"
    # fi
    # id=$((id + 1))
}
```

#### 3.1.3 `ufw::display_menu()`
```bash
# @type:        Filter
# @description: Отображает пункты меню пользователю
# @params:      нет
# @stdin:       id|text\0 (0..N)
# @stdout:      id|text\0 (0..N) - передает данные дальше
# @exit_code:   0 - успешно
```

**Реализация:**
```bash
ufw::display_menu() {
    local id_text
    local id
    local text
    
    log::draw_lite_border
    log_info "Доступные действия:"
    
    while IFS='|' read -r -d '' id_text || break; do
        id="${id_text%%|*}"
        text="${id_text#*|}"
        log_info_simple_tab "$id. $text"
        printf '%s|%s\0' "$id" "$text"
    done
    
    log_info_simple_tab "0. Выход"
    log::draw_lite_border
}
```

#### 3.1.4 `ufw::select_action()`
```bash
# @type:        Filter
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
# @params:      нет
# @stdin:       id|text\0 (0..N)
# @stdout:      id\0 (0..1) - выбранный ID или 0 (выход)
# @exit_code:   0 - успешно
#               2 - выход по запросу пользователя
```

**Реализация:**
```bash
ufw::select_action() {
    local -a menu_items=()
    local max_id=0
    local id_text
    
    # Читаем все пункты в массив
    while IFS= read -r -d '' id_text || break; do
        menu_items+=("$id_text")
        local id="${id_text%%|*}"
        (( id > max_id )) && max_id=$id
    done
    
    # Формируем паттерн для валидации
    local pattern="^[0-$max_id]$"
    
    # Запрашиваем выбор
    local selection
    selection=$(io::ask_value "Выберите действие" "" "$pattern" "0-$max_id" | tr -d '\0') || return
    
    # Если выбран 0 - выход
    if [[ "$selection" == "0" ]]; then
        log_info "Выход из меню"
        return 2
    fi
    
    # Выводим выбранный ID
    printf '%s\0' "$selection"
}
```

#### 3.1.5 `ufw::execute_action()`
```bash
# @type:        Orchestrator
# @description: Выполняет выбранное действие на основе ID
# @params:      нет
# @stdin:       id\0 (0..1)
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от действия
```

**Реализация:**
```bash
ufw::execute_action() {
    local action_id
    read -r -d '' action_id
    
    case "$action_id" in
        1) ufw::toggle ;;
        # 2) ufw::toggle_ping ;;  # Для будущего использования
    esac
}
```

#### 3.1.6 `ufw::toggle()`
```bash
# @type:        Sink
# @description: Переключает состояние UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
```

**Реализация:**
```bash
ufw::toggle() {
    if ufw::is_active; then
        ufw::force_disable
    else
        ufw::force_enable
    fi
}
```

#### 3.1.7 `ufw::toggle_ping()` (для будущего использования)
```bash
# @type:        Sink
# @description: Переключает состояние пинга через UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - успешно
#               $? - код ошибки от ufw
```

**Реализация:**
```bash
ufw::toggle_ping() {
    # TODO: Реализовать логику переключения пинга
    log_warn "Функция управления пингом еще не реализована"
}
```

### 3.2 Модификация `modules/05-ufw-modify.sh`

#### 3.2.1 Обновление `orchestrator::dispatch_logic()`

**Текущая реализация:**
```bash
orchestrator::dispatch_logic() {
    ufw::log_active_ufw_rules
    log_info_simple_tab "1. Включить UFW"
    log_info_simple_tab "2. Деактивировать UFW"

    local user_action
    user_action=$(io::ask_value "Выберите действие" "" "^[12]$" "1/2" | tr -d '\0') || return

    case "$user_action" in
        1) ufw::force_enable ;;
        2) ufw::force_disable ;;
    esac
}
```

**Новая реализация:**
```bash
orchestrator::dispatch_logic() {
    ufw::log_active_ufw_rules
    
    # Потоковая обработка: генерация меню → отображение → выбор → выполнение
    ufw::get_menu_items | ufw::display_menu
    ufw::get_menu_items | ufw::select_action | ufw::execute_action
}
```

**Примечание:** Двойной вызов `ufw::get_menu_items()` необходим из-за интерактивного характера `ufw::select_action()`. В будущем можно оптимизировать через сохранение состояния.

## 4. Технические требования

### 4.1 Соответствие AGENTS.md

- ✅ Потоковая архитектура (Pipeline-first)
- ✅ NUL-разделители (\0) для передачи данных
- ✅ Чистота FD 1 (stdout) - только данные для следующего звена
- ✅ Диагностика FD 2 (stderr) - логи и интерфейс
- ✅ Запрет на eval
- ✅ Аннотации функций с контрактом
- ✅ Префиксы имен функций (ufw::)
- ✅ Переиспользование кода через общие хелперы

### 4.2 Размещение функций

| Функция | Расположение | Причина |
|---------|--------------|--------|
| `ufw::is_active()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::get_menu_items()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::display_menu()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::select_action()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::execute_action()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::toggle()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |
| `ufw::toggle_ping()` | `modules/05-ufw-helpers.sh` | UFW-специфичный хелпер |

### 4.3 Зависимости

- `lib/vars.conf` - константы проекта
- `lib/logging.sh` - функции логирования
- `lib/user_confirmation.sh` - функции взаимодействия с пользователем
- `modules/common-helpers.sh` - общие хелперы (существующие UFW функции)

## 5. План разработки

### Этап 1: Создание файла `modules/05-ufw-helpers.sh`
- [x] Создать файл с заголовком MODULE_TYPE: helper
- [ ] Реализовать `ufw::is_active()`
- [ ] Реализовать `ufw::get_menu_items()`
- [ ] Реализовать `ufw::display_menu()`
- [ ] Реализовать `ufw::select_action()`
- [ ] Реализовать `ufw::execute_action()`
- [ ] Реализовать `ufw::toggle()`
- [ ] Реализовать `ufw::toggle_ping()` (заглушка для будущего)

### Этап 2: Модификация `modules/05-ufw-modify.sh`
- [ ] Добавить source для `05-ufw-helpers.sh`
- [ ] Обновить `orchestrator::dispatch_logic()`

### Этап 3: Обновление документации
- [ ] Обновить `function_map.txt` с новыми функциями
- [ ] Проверить соответствие AGENTS.md

## 6. Расширяемость

### 6.1 Добавление новых пунктов меню
КОММЕНТРАИЙ ПОЛЬЗОВАТЕЛЯ - РАСШИРЯЕМОСТЬ ТОЛЬКО ПРИНИМАЕМ К СВЕДЕНИЮ, НО НЕ РЕАЛИЗУЕМ НИЧЕГО ИЗ ПРЕДЛОЕННОГО НИЖЕ - НИКАКИХ ПРОВЕРОК НА ВКЛЮЧЕННЫЙ ПИНГ НЕ ДЕЛАЕМ - ЭТОТ ФУНКЦИОНАЛ ПОКА НЕ СПРОЕКТИРОВАН И БУДЕТ РЕАЛИЗОВЫВАТЬСЯ ОТДЕЛЬНО!
Для добавления нового пункта меню (например, управление пингом):

1. Реализовать функцию проверки состояния:
```bash
ufw::is_ping_blocked() {
    # Проверка, заблокирован ли пинг
    ufw status numbered | grep -q "deny.*icmp"
}
```

2. Добавить пункт в `ufw::get_menu_items()`:
```bash
# Пункт для переключения пинга
if ufw::is_ping_blocked; then
    printf '%s|%s\0' "$id" "Включить пинг"
else
    printf '%s|%s\0' "$id" "Отключить пинг"
fi
id=$((id + 1))
```

3. Реализовать действие в `ufw::toggle_ping()`:
```bash
ufw::toggle_ping() {
    if ufw::is_ping_blocked; then
        ufw delete deny icmp
    else
        ufw deny icmp comment "$BSSS_MARKER_COMMENT"
    fi
}
```

4. Добавить case в `ufw::execute_action()`:
```bash
2) ufw::toggle_ping ;;
```

### 6.2 Принципы расширения

- ✅ Добавлять новые функции без изменения существующей логики
- ✅ Использовать префикс `ufw::` для всех UFW-функций
- ✅ Соблюдать контракты функций (stdin/stdout/exit_code)
- ✅ Использовать NUL-разделители для передачи данных
- ✅ Логирование в stderr, данные в stdout

## 7. Риски и митигация

| Риск | Вероятность | Влияние | Митигация |
|------|-------------|---------|-----------|
| UFW не установлен | Среднее | Высокое | Проверка в check-модуле |
| Некорректный статус UFW | Низкое | Среднее | Обработка ошибок в `ufw::is_active()` |
| Проблемы с NUL-разделителями | Низкое | Среднее | Тестирование на различных данных |
| Сложность расширения | Низкое | Низкое | Четкая документация и примеры |

## 8. Критерии успеха

- [x] Меню формируется динамически на основе состояния UFW
- [ ] Пункт "Включить UFW" показывается, когда UFW inactive
- [ ] Пункт "Выключить UFW" показывается, когда UFW active
- [ ] Пункт 0 (выход) всегда доступен
- [ ] Архитектура соответствует AGENTS.md
- [ ] Код переиспользуем и легко расширяем
- [ ] Все функции имеют аннотации с контрактами
- [ ] Используются NUL-разделители для передачи данных

## 9. Приложение: Пример потока данных

### Сценарий 1: UFW неактивен

```
ufw::get_menu_items → 1|Включить UFW\0
ufw::display_menu → [вывод меню пользователю]
ufw::select_action → 1\0 (пользователь выбрал 1)
ufw::execute_action → ufw::toggle → ufw::force_enable
```

### Сценарий 2: UFW активен

```
ufw::get_menu_items → 1|Выключить UFW\0
ufw::display_menu → [вывод меню пользователю]
ufw::select_action → 1\0 (пользователь выбрал 1)
ufw::execute_action → ufw::toggle → ufw::force_disable
```

### Сценарий 3: Выход

```
ufw::get_menu_items → 1|Выключить UFW\0
ufw::display_menu → [вывод меню пользователю]
ufw::select_action → 0\0 (пользователь выбрал 0)
[выход из меню]
```

## 10. Заключение

Данный PRD определяет архитектуру и план разработки динамического меню UFW с использованием потоковой архитектуры и NUL-разделителей. Реализация будет соответствовать философии проекта Bash-инженерия 2026 и обеспечит легкую расширяемость для будущих функций.
