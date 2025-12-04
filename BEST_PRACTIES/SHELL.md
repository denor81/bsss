Анализ эталонного скрипта ../oneline-runner.sh

## Лучшие практики в скрипте

### 1. **Безопасность и надежность**
```bash
set -Eeuo pipefail
```
- **`-e`** - немедленный выход при ошибке любой команды
- **`-u`** - обработка неинициализированных переменных как ошибка
- **`-o pipefail`** - учитывает ошибки в пайплайнах
- **`-E`** - наследование trap в функциях

### 2. **Управление временными ресурсами**
```bash
TEMP_PROJECT_DIR=$(mktemp -d --tmpdir "$UTIL_NAME"-XXXXXX)
CLEANUP_COMMANDS+=("rm -rf $TEMP_PROJECT_DIR")
```
- Использование `mktemp` для создания уникальных временных файлов
- Массив `CLEANUP_COMMANDS` для централизованной очистки
- Обработка очистки даже при прерывании скрипта

### 3. **Обработка ошибок и исключений**
```bash
trap 'cleanup_handler EXIT' EXIT
trap 'cleanup_handler ERR' ERR
```
- Обработка как нормального завершения (EXIT), так и ошибок (ERR)
- Гарантированная очистка ресурсов в любом сценарии

### 4. **Модульность и читаемость**
```bash
check_root_permissions() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Для работы скрипта требуются права root"
        return "$ERR_NO_ROOT"
    fi
}
```
- Каждая функция выполняет одну конкретную задачу
- Четкие и понятные имена функций на английском

### 5. **Консистентное логирование**
```bash
readonly SYMBOL_SUCCESS="[V]"
readonly SYMBOL_QUESTION="[?]"
readonly SYMBOL_INFO="[ ]"
readonly SYMBOL_ERROR="[X]"

log_success() { echo "$SYMBOL_SUCCESS $1"; }
log_error() { echo "$SYMBOL_ERROR $1" >&2; }
log_info() { echo "$SYMBOL_INFO $1"; }
```
- Унифицированный формат вывода сообщений
- Разделение потоков (stderr для ошибок)
- Визуальные маркеры статуса ([v], [x], [ ])

### 6. **Валидация пользовательского ввода**
```bash
while true; do
    read -p "$SYMBOL_QUESTION Ваш выбор (Y/n/c): " -r
    input=${REPLY:-Y}
    
    if [[ ${input,,} =~ ^[ync]$ ]]; then
        choice=${input,,}
        break
    fi
    echo "Неверный выбор..."
done
```
- Проверка корректности ввода
- Обработка пустого ввода (значение по умолчанию)
- Регистронезависимая проверка
- Бесконечный цикл до получения корректного ввода

### 7. **Контроль зависимостей и состояний**
```bash
if [[ "$CLEANUP_DONE_FLAG" == "true" ]]; then
    return "$SUCCESS"
fi
```
- Защита от повторного выполнения критических операций
- Флаги состояния для управления потоком выполнения

## Стилистика кода с примерами

### 1. **Нейминг и структура**
```bash
# Константы в UPPER_CASE с префиксом
readonly ERR_ALREADY_INSTALLED=1
readonly ARCHIVE_URL="https://github.com/..."

# Флаги в CamelCase с суффиксом _FLAG
ONETIME_RUN_FLAG=false
SYS_INSTALL_FLAG=false

# Локальные переменные в lowercase
local fsize=""
local tar_output=""
```

### 10. **Использование констант для хардкод-значений**
```bash
# Все хардкод-значения выносим в константы в начале файла
readonly REBOOT_REQUIRED_FILE="/var/run/reboot-required"
readonly CONFIG_DIR="/etc/myapp"
readonly LOG_FILE="/var/log/myapp.log"

# Допускается хардкод только при подключении через source
# shellcheck disable=SC1091
source "${MAIN_DIR_PATH}/../lib/logging.sh"
```

### 2. **Комментирование**
```bash
# Многострочные комментарии для блоков кода
# -----------------------------------------
# Проверяем права root
# Проверяем, установлен ли уже скрипт
# Создаём временную директорию

# Инлайн-комментарии для пояснений
TEMP_PROJECT_DIR=$(mktemp -d --tmpdir "$UTIL_NAME"-XXXXXX)
CLEANUP_COMMANDS+=("rm -rf $TEMP_PROJECT_DIR")  # Добавляем в список очистки
```

### 3. **Обработка ошибок с детализацией**
```bash
curl_output=$(curl -fsSL "$ARCHIVE_URL" -o "$TMPARCHIVE" 2>&1 ) || { 
    log_error "Ошибка загрузки архива - $curl_output"  # Вывод конкретной ошибки
    return $ERR_DOWNLOAD
}

# Детальная информация при успехе
fsize=$(stat -c "%s" "$TMPARCHIVE" | awk '{printf "%.2f KB\n", $1/1024}')
log_info "Архив скачан в $TMPARCHIVE (размер: $fsize, тип: $(file -ib "$TMPARCHIVE"))"
```

### 4. **Структура условных операторов**
```bash
# Ясная последовательность условий
if [[ $choice =~ ^[Cc]$ ]]; then
    # Отмена
elif [[ $choice =~ ^[Nn]$ ]]; then
    # Установка
elif [[ $choice =~ ^[Yy]$ ]]; then
    # Разовый запуск
else
    # Ошибка
fi

# Проверка флагов состояния
if [[ "$ONETIME_RUN_FLAG" == "true" ]]; then
    onetime_run "$@"
fi
```

### 5. **Работа с путями и файлами**
```bash
# Поиск файла с проверкой
TMP_LOCAL_RUNNER_PATH=$(find "$TEMP_PROJECT_DIR" -type f -name "$LOCAL_RUNNER_FILE_NAME")
if [[ -z "$TMP_LOCAL_RUNNER_PATH" ]]; then
    log_error "Файл $LOCAL_RUNNER_FILE_NAME не найден"
fi

# Работа с директориями
tmp_dir_path=$(dirname "$TMP_LOCAL_RUNNER_PATH")
mkdir -p "$INSTALL_DIR"  # -p для создания вложенных директорий
```

### 6. **Форматирование вывода**
```bash
# Единообразное форматирование размеров
fsize=$(stat -c "%s" "$TMPARCHIVE" | awk '{printf "%.2f KB\n", $1/1024}')
dir_size=$(du -sb "$TEMP_PROJECT_DIR" | cut -f1 | awk '{printf "%.2f KB\n", $1/1024}')

# Информативные сообщения
log_info "Создана временная директория $TEMP_PROJECT_DIR"
log_info "Исполняемый файл $LOCAL_RUNNER_FILE_NAME найден"
```

### 7. **Архитектурные паттерны**
```bash
# Шаблон "командной строки" для очистки
CLEANUP_COMMANDS+=("rm -rf $TEMP_PROJECT_DIR")
CLEANUP_COMMANDS+=("rm -f $TMPARCHIVE")

# Позднее выполнение в cleanup_handler
for i in "${!CLEANUP_COMMANDS[@]}"; do
    CMD="${CLEANUP_COMMANDS[$i]}"
    eval "$CMD"
done
```

### 8. **Документирование интерфейса**
```bash
# Четкое описание использования в шапке
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/...)

# Инструкции для пользователя в процессе работы
log_info "Для запуска: sudo $UTIL_NAME"
log_info "Для удаления: sudo $UTIL_NAME --uninstall"
log_info "Пожалуйста, запускайте с sudo"
```

## Ключевые принципы для инструкций LLM

1. **Принцип единственной ответственности** - каждая функция делает одну вещь
2. **Защитное программирование** - проверка всех предварительных условий
3. **Идемпотентность** - возможность безопасного повторного запуска
4. **Прозрачность** - детальное логирование всех операций
5. **Консистентность** - единый стиль во всем коде
6. **Документирование через код** - имена и структура должны быть самодокументирующимися
7. **Грациозная деградация** - понятные сообщения об ошибках и рекомендации

### 9. **Коды возврата и их использование**
```bash
# Определение кодов возврата в начале файла
readonly SUCCESS=0
readonly ERR_PARAM_PARSE=1
readonly ERR_UNINSTALL=2
readonly ERR_RUN_MAIN_SCRIPT=3

# Использование кодов возврата вместо "магических чисел"
if [[ ! -f "$UNINSTALL_PATHS" ]]; then
    log_error "Файл с путями для удаления не найден: $UNINSTALL_PATHS"
    return $ERR_UNINSTALL  # Вместо return 1
fi

# Возврат кода успеха при отмене операции пользователем
if [[ ! ${confirmation,,} =~ ^[y]$ ]]; then
    log_info "Удаление отменено"
    return $SUCCESS  # Вместо return 0
fi
```

- **Определите все коды возврата в начале файла** с понятными именами
- **Используйте семантические имена** вместо "магических чисел"
- **Группируйте похожие коды** (например, все ошибки парсинга параметров)
- **Возвращайте SUCCESS при отмене операции пользователем** - это не ошибка, а осознанный выбор
- **Документируйте каждый код возврата** в комментариях при определении

Этот скрипт демонстрирует профессиональный подход к написанию bash-скриптов, сочетающий безопасность, надежность и удобство сопровождения.