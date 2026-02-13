#!/usr/bin/env bash
# Шаблон для создания интерактивных меню в модулях BSSS
# 
# Паттерн: Source → Sink (display) → Filter (select) → Orchestrator (dispatch)
# 
# ИСПОЛЬЗОВАНИЕ:
#   1. Скопируйте этот файл или его функции в ваш модуль
#   2. Замените "domain" на имя вашего модуля (например, "ssh", "ufw", "permissions")
#   3. Адаптируйте get_items() для генерации пунктов меню
#   4. Реализуйте dispatch_logic() для обработки выбора
#
# ПРИМЕР РЕАЛИЗАЦИИ:
#   См. modules/helpers/ufw.sh и modules/helpers/permissions.sh

# ==============================================================================
# SOURCE ФУНКЦИИ (Генерация данных)
# ==============================================================================

# @type:        Source
# @description: Генерирует пункты меню в формате id|text\0
#               Каждая строка: "идентификатор|описание\0"
#               ID должен быть числом для упрощения валидации
# @stdin:       нет
# @stdout:      id|text\0 (NUL-separated lines)
# @exit_code:   0 - всегда
# 
# ПРИМЕР:
#   domain::menu::get_items() {
#       printf '%s|%s\0' "1" "Действие 1"
#       printf '%s|%s\0' "2" "Действие 2"
#       printf '%s|%s\0' "0" "Выход"
#   }
domain::menu::get_items() {
    printf '%s|%s\0' "1" "Действие 1"
    printf '%s|%s\0' "2" "Действие 2"
    printf '%s|%s\0' "0" "Выход"
}

# ==============================================================================
# SINK ФУНКЦИИ (Отображение)
# ==============================================================================

# @type:        Sink
# @description: Отображает меню пользователю
#               Читает пункты из get_items() и выводит в stderr
# @stdin:       нет (вызывает get_items() напрямую)
# @stdout:      нет (вывод только в stderr через log_* функции)
# @exit_code:   0 - всегда
# 
# ПРИМЕР ВЫЗОВА:
#   domain::menu::display
#
# СТРУКТУРА ВЫВОДА:
#   ┌───────────────────┐
#   │ Меню модуля:     │  <-- log_info "$(_ "common.menu_header")"
#   │ 1. Действие 1    │  <-- log_info_simple_tab
#   │ 2. Действие 2    │
#   │ 0. Выход         │
#   └───────────────────┘
domain::menu::display() {
    local id text

    log_info "$(_ "common.menu_header")"

    while IFS='|' read -r -d '' id text || break; do
        log_info_simple_tab "$(_ "no_translate" "$id. $text")"
    done < <(domain::menu::get_items)
}

# ==============================================================================
# FILTER ФУНКЦИИ (Фильтрация и выбор)
# ==============================================================================

# @type:        Filter
# @description: Подсчитывает количество пунктов меню
# @stdin:       нет (вызывает get_items() напрямую)
# @stdout:      count (число пунктов меню)
# @exit_code:   0 - всегда
# 
# ИСПОЛЬЗУЕТСЯ В: get_user_choice() для построения валидационного паттерна
domain::menu::count_items() {
    domain::menu::get_items | grep -cz '^'
}

# @type:        Filter
# @description: Запрашивает выбор пользователя и возвращает выбранный ID
#               Использует io::ask_value для получения валидного ввода
# @stdin:       нет
# @stdout:      id\0 (выбранный идентификатор, NUL-terminated)
# @exit_code:   0 - выбор сделан
#               2 - отмена пользователем (выбран пункт 0)
# 
# ПРИМЕР ВЫЗОВА:
#   menu_id=$(domain::menu::get_user_choice | tr -d '\0')
#   case "$menu_id" in
#       1) domain::action_one ;;
#       2) domain::action_two ;;
#   esac
#
# ВАЛИДАЦИЯ:
#   - Автоматически строит паттерн ^[0-N]$ где N - количество пунктов - 1
#   - Пункт 0 (выход) возвращает код 2 для обработки как отмена
domain::menu::get_user_choice() {
    local qty_items=$(($(domain::menu::count_items) - 1))
    local pattern="^[0-$qty_items]$"
    local hint="0-$qty_items"

    io::ask_value "$(_ "domain.menu.select_prompt")" "" "$pattern" "$hint" "0"
}

# ==============================================================================
# VALIDATOR ФУНКЦИИ (Проверки)
# ==============================================================================

# @type:        Validator
# @description: Проверяет, что ID меню валидный
# @params:
#   menu_id     Идентификатор пункта меню для проверки
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - ID валидный
#               1 - ID невалидный
#
# ИСПОЛЬЗОВАНИЕ:
#   Опционально, для дополнительной валидации в dispatch_logic()
domain::menu::is_valid_id() {
    local menu_id="$1"
    local max_id=$(($(domain::menu::count_items) - 1))

    [[ "$menu_id" =~ ^[0-9]+$ ]] && (( menu_id <= max_id ))
}

# ==============================================================================
# ORCHESTRATOR ФУНКЦИИ (Координация)
# ==============================================================================

# @type:        Orchestrator
# @description: Диспетчеризация действий по выбранному пункту меню
#               Обрабатывает выбор пользователя и выполняет соответствующее действие
# @params:
#   menu_id     Идентификатор выбранного пункта меню
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действие выполнено успешно
#               $? - код ошибки от выполненного действия (автоматический проброс)
#
# ПРИМЕР:
#   domain::orchestrator::dispatch_menu() {
#       local menu_id="$1"
#
#       case "$menu_id" in
#           1) domain::action_one ;;
#           2) domain::action_two ;;
#           *) log_error "$(_ "domain.error.invalid_menu_id" "$menu_id")"; return 1 ;;
#       esac
#   }
#
# ВАЖНО:
#   - Нет явных return - код возврата пробрасывается автоматически
#   - io::ask_value сама возвращает код 2 при выборе cancel_keyword (пункт 0)
#   - dispatch_menu никогда не получит menu_id == 0 (это обрабатывает io::ask_value)
domain::orchestrator::dispatch_menu() {
    local menu_id="$1"

    case "$menu_id" in
        1) echo "Выполнение действия 1" ;;
        2) echo "Выполнение действия 2" ;;
        *)
            log_error "$(_ "domain.error.invalid_menu_id" "$menu_id")"
            return 1
            ;;
    esac
}

# @type:        Orchestrator
# @description: Основная точка входа для работы с меню
#               Отображает меню, получает выбор пользователя, выполняет действие
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 - действие выполнено успешно
#               2 - выход по запросу пользователя
#               $? - код ошибки
#
# ПРИМЕР ВЫЗОВА В МОДУЛЕ:
#   domain::menu::run
#
# ПОСЛЕДОВАТЕЛЬНОСТЬ:
#   1. Отображение меню (display)
#   2. Получение выбора пользователя (get_user_choice)
#   3. Диспетчеризация действий (dispatch_menu)
#
# ВАЖНО:
#   - Запуск get_user_choice и dispatch_menu в текущем процессе,
#     а не через pipe, для корректной обработки сигналов (например, SIGUSR1)
#   - См. комментарии в modules/ufw-modify.sh строки 176-186
domain::menu::run() {
    domain::menu::display

    local menu_id
    menu_id=$(domain::menu::get_user_choice | tr -d '\0')

    domain::orchestrator::dispatch_menu "$menu_id"
}

# ==============================================================================
# ДОПОЛНИТЕЛЬНЫЕ ВОЗМОЖНОСТИ
# ==============================================================================

# ДИНАМИЧЕСКАЯ ГЕНЕРАЦИЯ ПУНКТОВ МЕНЮ НА ОСНОВЕ СОСТОЯНИЯ:
#
# Пример из UFW модуля:
#   ufw::menu::get_items() {
#       ufw::status::is_active && printf '%s|%s\0' "1" "Отключить UFW" || printf '%s|%s\0' "1" "Включить UFW"
#       ufw::ping::is_configured && printf '%s|%s\0' "2" "Разрешить пинг" || printf '%s|%s\0' "2" "Запретить пинг"
#       printf '%s|%s\0' "0" "Выход"
#   }
#
# ПРЕИМУЩЕСТВА:
#   - Меню всегда актуально
#   - Нет жестко зашитых текстов
#   - Легко добавлять новые состояния

# УСЛОВНОЕ ОТОБРАЖЕНИЕ СТАТУСОВ:
#
# Пример из permissions модуля:
#   permissions::menu::display() {
#       permissions::orchestrator::log_statuses  # Логируем текущее состояние
#       log_info "$(_ "common.menu_header")"     # Затем показываем меню
#       # ... стандартный цикл отображения ...
#   }
#
# ПРЕИМУЩЕСТВА:
#   - Пользователь видит контекст перед выбором
#   - Понятно, какие изменения возможны

# ==============================================================================
# ГАЙДЛАЙНЫ ПО СОЗДАНИЮ НОВОГО МЕНЮ
# ==============================================================================

# ШАГ 1: Создайте функции get_items(), display(), get_user_choice()
#   - Скопируйте шаблон из этого файла
#   - Замените "domain" на имя вашего модуля
#
# ШАГ 2: Реализуйте get_items() для генерации пунктов меню
#   - Используйте printf '%s|%s\0' "id" "text"
#   - ID должны быть числами для простоты валидации
#   - Всегда включайте пункт "0" для выхода
#
# ШАГ 3: Реализуйте dispatch_logic() для обработки выбора
#   - Используйте case с menu_id
#   - Возвращайте 0 при успехе
#   - Возвращайте 2 для отмены (пункт 0)
#   - Возвращайте 1 для ошибок
#
# ШАГ 4: Добавьте вызов в ваш модуль
#   - domain::menu::run  # для автозапуска
#   # или
#   - domain::menu::display
#     menu_id=$(domain::menu::get_user_choice | tr -d '\0')
#     domain::orchestrator::dispatch_logic "$menu_id"
#
# ШАГ 5: Добавьте переводы в lib/i18n/ru/domain.sh и lib/i18n/en/domain.sh
#   - domain.menu.select_prompt
#   - domain.error.invalid_menu_id
#   - domain.menu.item_*
#
# ПРИМЕРЫ РЕАЛИЗАЦИИ:
#   - modules/helpers/ufw.sh (полный пример)
#   - modules/helpers/permissions.sh (полный пример)
#   - modules/ufw-modify.sh (интеграция в модуль)
#   - modules/permissions-modify.sh (интеграция в модуль)

# ==============================================================================
# КОНЕЦ ШАБЛОНА
# ==============================================================================
