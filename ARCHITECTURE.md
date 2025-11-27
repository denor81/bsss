# Архитектура проекта Basic Server Security Setup (BSSS)

## Обзор архитектуры

Проект BSSS использует модульную архитектуру с загрузчиком, который обеспечивает работу в режиме one-line команды через wget/curl с локальным кешированием модулей.

```
bsss/
├── launcher.sh              # Загрузчик (точка входа)
├── bsss-main.sh            # Основной скрипт
├── modules/                # Директория с модулями
│   ├── system-check.sh     # Проверка перезагрузки
│   ├── system-update.sh    # Обновление системы
│   ├── ssh-port.sh         # Настройка SSH порта
│   ├── ipv6-disable.sh     # Отключение IPv6
│   ├── ssh-auth.sh         # Настройка авторизации SSH
│   ├── ufw-setup.sh        # Настройка UFW
│   └── helpers/            # Вспомогательные функции
│       ├── common.sh       # Общие функции
│       ├── config.sh       # Работа с конфигурациями
│       ├── input.sh        # Обработка пользовательского ввода
│       └── logging.sh       # Логирование
└── tests/                  # Тестовое окружение
    ├── mock-environments/  # Mock окружения для тестов
    └── test-runner.sh      # Запуск тестов
```

## 1. Архитектура загрузчика (launcher.sh)

### 1.1. Назначение
- Обеспечение работы в режиме one-line команды
- Управление локальным кешированием модулей
- Проверка и загрузка зависимостей

### 1.2. Механизм работы
```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Конфигурация загрузчика
readonly CACHE_BASE="${HOME}/.cache/bsss"
readonly REMOTE_BASE="https://raw.githubusercontent.com/user/repo/main"
readonly SCRIPT_VERSION="1.0.0"

# Функция загрузки модуля при отсутствии
download_if_missing() {
    local file="$1"
    local remote_path="$2"
    local cache_file="${CACHE_BASE}/${file}"
    
    if [[ ! -f "$cache_file" ]]; then
        mkdir -p "$CACHE_BASE"
        curl -s "${REMOTE_BASE}/${remote_path}" -o "$cache_file"
        chmod +x "$cache_file"
    fi
}

# Проверка и загрузка всех необходимых модулей
load_dependencies() {
    download_if_missing "helpers/common.sh" "modules/helpers/common.sh"
    download_if_missing "helpers/config.sh" "modules/helpers/config.sh"
    download_if_missing "helpers/input.sh" "modules/helpers/input.sh"
    download_if_missing "helpers/logging.sh" "modules/helpers/logging.sh"
    download_if_missing "system-check.sh" "modules/system-check.sh"
    download_if_missing "system-update.sh" "modules/system-update.sh"
    download_if_missing "ssh-port.sh" "modules/ssh-port.sh"
    download_if_missing "ipv6-disable.sh" "modules/ipv6-disable.sh"
    download_if_missing "ssh-auth.sh" "modules/ssh-auth.sh"
    download_if_missing "ufw-setup.sh" "modules/ufw-setup.sh"
    download_if_missing "bsss-main.sh" "bsss-main.sh"
}

# Загрузка модулей и запуск основного скрипта
main() {
    load_dependencies
    
    # Подключение вспомогательных модулей
    source "${CACHE_BASE}/helpers/common.sh"
    source "${CACHE_BASE}/helpers/config.sh"
    source "${CACHE_BASE}/helpers/input.sh"
    source "${CACHE_BASE}/helpers/logging.sh"
    
    # Запуск основного скрипта с передачей аргументов
    source "${CACHE_BASE}/bsss-main.sh" "$@"
}

main "$@"
```

### 1.3. Использование
```bash
# One-line команда запуска
curl -s https://raw.githubusercontent.com/user/repo/main/launcher.sh | bash -s -- "$@"
```

## 2. Архитектура основного скрипта (bsss-main.sh)

### 2.1. Глобальные переменные состояния
```bash
# Глобальная переменная для хранения SSH порта между шагами
declare -g SSH_PORT=""
```

### 2.2. Флаги командной строки
```bash
declare -g CHECK_MODE=false
declare -g DEFAULT_MODE=false
declare -g VERBOSE_MODE=false
```

### 2.3. Структура основного скрипта
```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Подключение модулей
source "${CACHE_BASE}/system-check.sh"
source "${CACHE_BASE}/system-update.sh"
source "${CACHE_BASE}/ssh-port.sh"
source "${CACHE_BASE}/ipv6-disable.sh"
source "${CACHE_BASE}/ssh-auth.sh"
source "${CACHE_BASE}/ufw-setup.sh"

# Функция парсинга аргументов
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                CHECK_MODE=true
                shift
                ;;
            --default)
                DEFAULT_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            *)
                echo "Неизвестный параметр: $1" >&2
                exit 1
                ;;
        esac
    done
}

# Основная функция выполнения
main() {
    parse_arguments "$@"
    
    # Проверка прав
    check_root_permissions
    
    # Последовательное выполнение шагов
    execute_step "system_check" "Проверка необходимости перезагрузки"
    execute_step "system_update" "Обновление системы"
    execute_step "ssh_port" "Настройка SSH порта"
    execute_step "ipv6_disable" "Отключение IPv6"
    execute_step "ssh_auth" "Настройка авторизации SSH"
    execute_step "ufw_setup" "Настройка брандмауэра"
}

# Универсальная функция выполнения шага
execute_step() {
    local step_function="$1"
    local step_description="$2"
    
    log_step "$step_description"
    
    if [[ "$CHECK_MODE" == true ]]; then
        "${step_function}" --check
    elif [[ "$DEFAULT_MODE" == true ]]; then
        if [[ "$step_function" =~ ^(ssh_port|ipv6_disable|ssh_auth|ufw_setup)$ ]]; then
            "${step_function}" --default
        fi
    else
        "${step_function}"
    fi
}

main "$@"
```

## 3. Архитектура модулей

### 3.1. Универсальная структура модуля
Каждый модуль следует единой структуре:

```bash
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# 3.1.0. Исходные данные
module_init() {
    local parameter_name=""
    local parameter_value=""
    local config_dir=""
    local main_config_file=""
    local default_value=""
}

# 3.1.1. Проверка текущего состояния
check_current_state() {
    # Возвращает: значение параметра и файл или "notfound"
    # Реализация специфична для каждого модуля
}

# 3.1.2. Формирование имени нового файла правила
generate_filename() {
    # Генерирует имя файла с правильным индексом
}

# 3.1.3. Создание и сохранение файла
create_config_file() {
    # Создает файл конфигурации
}

# 3.1.4. Применение настроек
apply_settings() {
    # Применяет изменения системы
}

# Основная функция модуля
module_main() {
    local mode="${1:-normal}"
    
    case "$mode" in
        --check)
            check_current_state
            ;;
        --default)
            restore_default_settings
            ;;
        *)
            module_init
            local current_state
            current_state=$(check_current_state)
            
            if [[ "$current_state" != "notfound" ]]; then
                # Логика обработки текущего состояния
            fi
            
            generate_filename
            create_config_file
            apply_settings
            ;;
    esac
}
```

### 3.2. Модуль system-check.sh
```bash
#!/usr/bin/env bash

check_reboot_required() {
    if [[ -f /var/run/reboot-required ]]; then
        echo "Требуется перезагрузка системы. Выполните перезагрузку и запустите скрипт снова."
        exit 1
    fi
}
```

### 3.3. Модуль ssh-port.sh
```bash
#!/usr/bin/env bash

# Исходные данные
SSH_PORT_DEFAULT="22"
SSH_CONFIG_DIR="/etc/ssh/sshd_config.d"
SSH_MAIN_CONFIG="/etc/ssh/sshd_config"

check_ssh_port() {
    # Поиск активного параметра Port в иерархии файлов
    local port_value=""
    local port_file=""
    
    # Проверка основного файла
    if [[ -f "$SSH_MAIN_CONFIG" ]]; then
        port_value=$(grep -E '^\s*Port\s+[0-9]+' "$SSH_MAIN_CONFIG" | tail -1 | awk '{print $2}')
        if [[ -n "$port_value" ]]; then
            port_file="$SSH_MAIN_CONFIG"
        fi
    fi
    
    # Проверка файлов в .d директории
    if [[ -d "$SSH_CONFIG_DIR" ]]; then
        while IFS= read -r -d '' config_file; do
            local file_port
            file_port=$(grep -E '^\s*Port\s+[0-9]+' "$config_file" | tail -1 | awk '{print $2}')
            if [[ -n "$file_port" ]]; then
                port_value="$file_port"
                port_file="$config_file"
            fi
        done < <(find "$SSH_CONFIG_DIR" -name "*.conf" -type f -print0 | sort -z)
    fi
    
    if [[ -n "$port_value" ]]; then
        echo "${port_value}:${port_file}"
    else
        echo "notfound"
    fi
}
```

## 4. Архитектура вспомогательных функций

### 4.1. modules/helpers/common.sh
```bash
#!/usr/bin/env bash

# Проверка прав root
check_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        echo "Этот скрипт требует прав root или sudo" >&2
        exit 1
    fi
}

# Проверка наличия systemd
check_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        echo "Система не использует systemd. Выход." >&2
        exit 1
    fi
}

# Проверка доступности директории для записи
check_write_permission() {
    local dir="$1"
    if [[ ! -w "$dir" ]]; then
        echo "Нет прав на запись в директорию: $dir" >&2
        exit 1
    fi
}
```

### 4.2. modules/helpers/config.sh
```bash
#!/usr/bin/env bash

# Поиск последнего активного параметра в конфигурационных файлах
find_last_active_parameter() {
    local param_name="$1"
    local main_config="$2"
    local config_dir="$3"
    
    local last_value=""
    local last_file=""
    
    # Проверка основного файла
    if [[ -f "$main_config" ]]; then
        last_value=$(grep -E "^\s*${param_name}\s+" "$main_config" | tail -1 | sed "s/^\s*${param_name}\s\+\(.*\)/\1/")
        if [[ -n "$last_value" ]]; then
            last_file="$main_config"
        fi
    fi
    
    # Проверка файлов в .d директории
    if [[ -d "$config_dir" ]]; then
        while IFS= read -r -d '' config_file; do
            local file_value
            file_value=$(grep -E "^\s*${param_name}\s+" "$config_file" | tail -1 | sed "s/^\s*${param_name}\s\+\(.*\)/\1/")
            if [[ -n "$file_value" ]]; then
                last_value="$file_value"
                last_file="$config_file"
            fi
        done < <(find "$config_dir" -name "*.conf" -type f -print0 | sort -z)
    fi
    
    if [[ -n "$last_value" ]]; then
        echo "${last_value}:${last_file}"
    else
        echo "notfound"
    fi
}

# Генерация индекса для нового файла конфигурации
generate_config_index() {
    local last_file="$1"
    local default_index="10"
    local max_index="99"
    
    if [[ "$last_file" == "notfound" ]]; then
        echo "$default_index"
        return
    fi
    
    # Извлечение индекса из имени файла
    local basename
    basename=$(basename "$last_file")
    local index
    index=$(echo "$basename" | sed -E 's/^([0-9]+).*/\1/')
    
    if [[ -n "$index" && "$index" =~ ^[0-9]+$ ]]; then
        local new_index=$((index + 10))
        # Ограничение максимального индекса
        if ((new_index > max_index)); then
            echo "$max_index"
        else
            echo "$new_index"
        fi
    else
        echo "$default_index"
    fi
}
```

### 4.3. modules/helpers/input.sh
```bash
#!/usr/bin/env bash

# Функция подтверждения Y/n с Y по умолчанию
confirm_yes_no() {
    local prompt="$1"
    local response
    
    while true; do
        read -p "${prompt} [Y/n]: " response
        response=${response:-Y}
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Пожалуйста, введите Y или n"
                ;;
        esac
    done
}

# Ввод и валидация SSH порта
input_ssh_port() {
    local port
    while true; do
        read -p "Введите SSH порт (1-65535): " port
        
        # Удаление пробелов
        port=$(echo "$port" | tr -d ' ')
        
        # Проверка что это число и в допустимом диапазоне
        if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
            echo "$port"
            return 0
        else
            echo "Ошибка: порт должен быть числом от 1 до 65535"
        fi
    done
}
```

### 4.4. modules/helpers/logging.sh
```bash
#!/usr/bin/env bash

# Глобальная переменная для режима verbose
declare -g VERBOSE_MODE=false

# Инициализация логирования
init_logging() {
    VERBOSE_MODE="${1:-false}"
}

# Логирование шага
log_step() {
    local message="$1"
    echo "=== $message ==="
}

# Подробное логирование (только в verbose режиме)
log_verbose() {
    local message="$1"
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "  $message"
    fi
}

# Логирование состояния до/после
log_state_change() {
    local param="$1"
    local old_value="$2"
    local new_value="$3"
    
    echo "  $param: $old_value -> $new_value"
}
```

## 5. Архитектура тестового окружения

### 5.1. Структура тестового окружения
```
tests/
├── mock-environments/
│   ├── scenario-1/          # Базовый сценарий
│   │   ├── etc/
│   │   │   ├── ssh/
│   │   │   │   ├── sshd_config
│   │   │   │   └── sshd_config.d/
│   │   │   └── default/
│   │   │       ├── grub
│   │   │       └── grub.d/
│   ├── scenario-2/          # Существуют .d директории
│   ├── scenario-3/          # Есть правила в .d директориях
│   └── scenario-4/          # Конфликтующие правила
└── test-runner.sh
```

### 5.2. test-runner.sh
```bash
#!/usr/bin/env bash

# Запуск тестов для всех сценариев
run_all_tests() {
    local scenarios=("scenario-1" "scenario-2" "scenario-3" "scenario-4")
    
    for scenario in "${scenarios[@]}"; do
        echo "Тестирование сценария: $scenario"
        setup_test_environment "$scenario"
        run_scenario_tests "$scenario"
        cleanup_test_environment "$scenario"
    done
}
```

### 5.3. Тестирование загрузки модулей
```bash
#!/usr/bin/env bash

# Тестирование загрузки модулей из кеша
test_cached_modules() {
    # Создание тестового кеша с модулями
    local test_cache="${HOME}/.cache/bsss-test"
    mkdir -p "$test_cache"
    
    # Копирование модулей в тестовый кеш
    cp -r modules/* "$test_cache/"
    
    # Запуск с использованием тестового кеша
    CACHE_BASE="$test_cache" source bsss-main.sh --check
}

# Тестирование загрузки модулей с сервера
test_remote_modules() {
    # Очистка кеша для принудительной загрузки с сервера
    rm -rf "${HOME}/.cache/bsss"
    
    # Запуск загрузчика
    ./launcher.sh --check
}
```

## 6. Поток выполнения программы

### 6.1. Общий поток
```
1. launcher.sh загружает модули в кеш
2. bsss-main.sh парсит аргументы командной строки
3. Последовательное выполнение шагов:
   - system_check: проверка перезагрузки
   - system_update: обновление системы
   - ssh_port: настройка SSH порта (сохраняет SSH_PORT)
   - ipv6_disable: отключение IPv6
   - ssh_auth: настройка авторизации
   - ufw_setup: настройка брандмауэра (использует SSH_PORT)
4. Шаг ssh_port сохраняет SSH порт в глобальную переменную SSH_PORT
5. Шаг ufw_setup использует SSH_PORT для настройки правил файрвола
```

### 6.2. Поток выполнения отдельного шага
```
1. Проверка текущего состояния (check_current_state)
2. Если check режим: возврат состояния и выход
3. Если default режим: удаление bsss файлов и применение
4. Если normal режим:
   - Анализ текущего состояния
   - Запрос пользовательского ввода (если необходимо)
   - Формирование имени нового файла
   - Создание файла конфигурации (без изменения существующих файлов)
   - Применение изменений
```

## 7. Механизмы безопасности

### 7.1. Безопасность переменных
- Все переменные объявляются как local в функциях
- Глобальные переменные объявляются с declare -g
- Использование двойных кавычек для всех переменных

### 7.2. Безопасность команд
- Использование set -o errexit, nounset, pipefail
- Проверка входных данных
- Валидация путей файлов

### 7.3. Безопасность прав доступа
- Проверка прав root перед выполнением
- Проверка прав на запись в конфигурационные директории
- Создание резервных копий перед изменениями (опционально)

## 8. Расширяемость архитектуры

### 8.1. Добавление новых модулей
1. Создать файл модуля в modules/
2. Следовать универсальной структуре модуля
3. Добавить вызов в bsss-main.sh
4. Обновить загрузчик для включения нового модуля

### 8.2. Добавление новых вспомогательных функций
1. Создать файл в modules/helpers/
2. Следовать соглашениям об именовании
3. Добавить source в основной скрипт

### 8.3. Поддержка новых ОС
1. Создать ОС-специфичные модули
2. Использовать условную загрузку на основе определения ОС
3. Адаптировать пути команд и конфигурационных файлов