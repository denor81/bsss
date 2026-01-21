# Руководство для тест-агентов BSSS

## 1. Введение (Introduction)

### Обзор тестовой фреймворка

BSSS Testing Framework — это модульная система автоматического тестирования, предназначенная для проверки корректности работы фреймворка настройки системных параметров. Тестовая фреймворка построена на тех же принципах, что и основной проект: потоковая архитектура, атомарные операции и строгая изоляция тестов.

### Зачем нужен этот документ

Этот документ служит исчерпывающим руководством для тест-агентов, работающих с BSSS тестовой фреймворкой. Он объясняет:

- Как правильно создавать и запускать тестовые сценарии
- Критические моменты, которые необходимо учитывать
- Распространенные ошибки и способы их избежания
- Как расширять тестовую фреймворку
- Как отлаживать тесты

### Для кого предназначен

Это руководство предназначено для:

- Тест-агентов, создающих новые тестовые сценарии
- Разработчиков, модифицирующих существующие тесты
- Инженеров, обеспечивающих качество кода
- Любого, кто работает с тестовой фреймворкой BSSS

---

## 2. Архитектура тестов (Test Architecture)

### Структура тестового сценария

Каждый тестовый сценарий должен следовать единой структуре:

```bash
#!/usr/bin/env bash
# @name: test-name
# @description: Краткое описание теста
# @expected: Ожидаемый результат
# @timeout: Максимальное время выполнения (секунды)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test libraries
source "${SCRIPT_DIR}/../lib/test-logging.sh"
source "${SCRIPT_DIR}/../lib/test-parser.sh"

# Source project libraries
source "${PROJECT_ROOT}/lib/vars.conf"

# Test metadata
TEST_NAME="test-name"
TEST_DESCRIPTION="Описание теста"

# Setup function - подготовка окружения
test::setup() {
    # Подготовка окружения перед тестом
    # Например: создание временных файлов, настройка конфигураций
    ...
}

# Cleanup function - очистка после теста
test::cleanup() {
    # Очистка после теста
    # Например: удаление временных файлов, восстановление конфигураций
    ...
}

# Custom validation function - дополнительная валидация
test::custom_validate() {
    local log_file="$1"
    
    # Дополнительная валидация результатов теста
    # Например: проверка конкретных значений в логах
    ...
    
    return 0  # или 1 если валидация не прошла
}

# Main test function
test::run() {
    local log_file=""
    local exit_code=0
    
    # 1. Setup - подготовка окружения
    test::setup || return 1
    
    # 2. Create log file
    log_file=$(test::create_log_file "$TEST_NAME") || return 1
    
    # 3. Run test
    export TEST_MODE="true"
    export LOG_MODE="both"
    export LOG_FILE="$log_file"
    
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    # 4. Validate exit code
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        test::cleanup
        return 1
    fi
    
    # 5. Validate process lifecycle
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # 6. Custom validation (опционально)
    if ! test::custom_validate "$log_file"; then
        test::cleanup
        return 1
    fi
    
    # 7. Cleanup - очистка после теста
    test::cleanup
    
    return 0
}
```

### Основные компоненты теста

1. **Метаданные теста** (`@name`, `@description`, `@expected`, `@timeout`)
   - Используются для идентификации и документации теста
   - Парсятся [`test-parser.sh`](lib/test-parser.sh)

2. **Функция `test::setup()`**
   - Подготавливает окружение перед тестом
   - Обязательна для обеспечения изоляции тестов

3. **Функция `test::cleanup()`**
   - Очищает окружение после теста
   - Обязательна для обеспечения изоляции тестов

4. **Функция `test::custom_validate()`**
   - Дополнительная валидация результатов теста
   - Опциональна, но полезна для специфических проверок

5. **Функция `test::run()`**
   - Основная функция теста
   - Выполняет все шаги теста: setup → run → validate → cleanup

---

## 3. Критические моменты (Critical Points)

### 3.1. TEST_MODE Environment Variable

**КРИТИЧЕСКИ ВАЖНО:** ВСЕГДА устанавливайте `TEST_MODE=true` перед запуском BSSS.

**НЕ используйте piping ввода** (`echo "input" | command`) — это НЕ сработает!

**Почему piping не работает:**

Функция [`io::ask_value()`](../lib/user_confirmation.sh:24) читает ввод напрямую из `/dev/tty`, который обходит stdin. Это означает, что piping через `|` не передаст ввод в функцию.

**Правильный подход:**

```bash
# ✅ ПРАВИЛЬНО
export TEST_MODE="true"
export LOG_MODE="both"
export LOG_FILE="$log_file"
sudo bash "${PROJECT_ROOT}/local-runner.sh" -t

# ❌ НЕПРАВИЛЬНО - piping не сработает!
echo -e "Y\n2\nY\n" | sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
```

**Объяснение:**

- `TEST_MODE="true"` заставляет BSSS использовать тестовый режим, где интерактивные функции возвращают значения по умолчанию
- Piping не работает, потому что [`io::ask_value()`](../lib/user_confirmation.sh:24) читает из `/dev/tty`, а не из stdin
- Всегда используйте `TEST_MODE` для автоматизации тестов

### 3.2. Exit Code Handling

BSSS использует специфические exit codes:

- **Код 0:** Успех (success)
- **Код 2:** Отмена пользователем (cancellation) — ЭТО НЕ ОШИБКА!
- **Код 3:** Откат (rollback) — В сценариях rollback ЭТО ВАЛИДНЫЙ результат

**Валидация exit codes:**

```bash
# ✅ ПРАВИЛЬНО - валидируем код 0, 2, или 3
if ! test::validate_exit_code "$exit_code" "0,2,3"; then
    test::cleanup
    return 1
fi

# ❌ НЕПРАВИЛЬНО - валидируем только код 0
if [[ "$exit_code" -ne 0 ]]; then
    test::cleanup
    return 1
fi
```

**Объяснение:**

- Код 2 используется, когда пользователь отменяет операцию (например, через Ctrl+C)
- Код 3 используется в сценариях rollback для обозначения успешного отката
- Тесты должны валидировать эти коды как валидные результаты

### 3.3. Process Lifecycle Validation

**КРИТИЧЕСКИ ВАЖНО:** ВСЕГДА вызывайте `test::validate_lifecycle()`.

Эта функция проверяет, что каждый процесс имеет start и stop события в логах. Это обнаруживает orphaned процессы — процессы, которые были запущены, но не были остановлены.

**Пример:**

```bash
# ✅ ПРАВИЛЬНО - валидируем жизненный цикл процессов
test::run() {
    local log_file=""
    local exit_code=0
    
    test::setup || return 1
    log_file=$(test::create_log_file "$TEST_NAME") || return 1
    
    export TEST_MODE="true"
    export LOG_MODE="both"
    export LOG_FILE="$log_file"
    
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        test::cleanup
        return 1
    fi
    
    # КРИТИЧЕСКИ ВАЖНО: валидация жизненного цикла процессов
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    test::cleanup
    return 0
}
```

**Объяснение:**

- Process lifecycle validation обнаруживает процессы, которые не были остановлены
- Это критично для обнаружения утечек ресурсов
- Без этой проверки тест может пройти, но система останется в нестабильном состоянии

### 3.4. Setup и Cleanup

**КРИТИЧЕСКИ ВАЖНО:** ВСЕГДА реализуйте `test::setup()` и `test::cleanup()`.

Эти функции обеспечивают изоляцию тестов — каждый тест должен работать в чистом окружении и не влиять на другие тесты.

**Пример:**

```bash
# ✅ ПРАВИЛЬНО - есть изоляция тестов
test::setup() {
    # Создаем временную конфигурацию для теста
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bsss-test-backup
    
    # Устанавливаем тестовые значения
    echo "Port 22" | sudo tee /etc/ssh/sshd_config > /dev/null
    
    test::log_info "Setup completed"
}

test::cleanup() {
    # Восстанавливаем исходную конфигурацию
    if [[ -f /etc/ssh/sshd_config.bsss-test-backup ]]; then
        sudo mv /etc/ssh/sshd_config.bsss-test-backup /etc/ssh/sshd_config
    fi
    
    # Перезапускаем SSH для применения изменений
    sudo systemctl restart sshd || true
    
    test::log_info "Cleanup completed"
}
```

**Объяснение:**

- Setup подготавливает окружение перед тестом
- Cleanup восстанавливает окружение после теста
- Это гарантирует, что каждый тест запускается в чистом окружении
- Тесты не влияют друг на друга

---

## 4. Как расширять тесты (How to Extend Tests)

### 4.1. Добавление нового тестового сценария

**Шаг 1:** Скопируйте [`template.sh`](scenarios/template.sh)

```bash
cp tests/scenarios/template.sh tests/scenarios/my-new-test.sh
```

**Шаг 2:** Переименуйте файл

```bash
mv tests/scenarios/my-new-test.sh tests/scenarios/my-new-test.sh
```

**Шаг 3:** Измените метаданные

```bash
# @name: my-new-test
# @description: Описание вашего теста
# @expected: Ожидаемый результат
# @timeout: 60
```

**Шаг 4:** Реализуйте `test::setup()` - подготовка окружения

```bash
test::setup() {
    # Подготовка окружения для вашего теста
    ...
}
```

**Шаг 5:** Реализуйте `test::cleanup()` - очистка после теста

```bash
test::cleanup() {
    # Очистка после вашего теста
    ...
}
```

**Шаг 6:** Реализуйте `test::custom_validate()` - дополнительная валидация (опционально)

```bash
test::custom_validate() {
    local log_file="$1"
    
    # Дополнительная валидация результатов
    ...
    
    return 0
}
```

**Шаг 7:** Реализуйте `test::run()` - основной тест

```bash
test::run() {
    local log_file=""
    local exit_code=0
    
    test::setup || return 1
    log_file=$(test::create_log_file "$TEST_NAME") || return 1
    
    export TEST_MODE="true"
    export LOG_MODE="both"
    export LOG_FILE="$log_file"
    
    # Запуск вашего теста
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        test::cleanup
        return 1
    fi
    
    if ! test::validate_lifecycle "$log_file"; then
        test::cleanup
        return 1
    fi
    
    if ! test::custom_validate "$log_file"; then
        test::cleanup
        return 1
    fi
    
    test::cleanup
    return 0
}
```

**Шаг 8:** Сделайте файл исполняемым

```bash
chmod +x tests/scenarios/my-new-test.sh
```

**Шаг 9:** Запустите тест

```bash
sudo bash tests/test-runner.sh --scenario my-new-test
```

### 4.2. Добавление новой функции валидации

**Шаг 1:** Откройте [`../lib/test-parser.sh`](lib/test-parser.sh)

**Шаг 2:** Добавьте новую функцию с аннотациями:

```bash
# @type:        Validator
# @description: Описание функции валидации
# @stdin:       none
# @stdout:      none
# @exit_code:   0 - validation passed
#               1 - validation failed
test::validate_custom_rule() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        test::log_fail "CustomRule" "Log file not found: $log_file"
        return 1
    fi
    
    # Логика валидации
    local log_content
    log_content=$(cat "$log_file")
    
    # Пример: проверяем наличие определенной строки в логах
    if ! echo "$log_content" | grep -q "Expected pattern"; then
        test::log_fail "CustomRule" "Expected pattern not found in logs"
        return 1
    fi
    
    test::log_pass "CustomRule" "Validation passed"
    return 0
}
```

**Шаг 3:** Вызовите валидацию в `test::run()`:

```bash
test::run() {
    ...
    
    # Вызов вашей новой валидации
    if ! test::validate_custom_rule "$log_file"; then
        test::cleanup
        return 1
    fi
    
    ...
}
```

---

## 5. Как быть уверенным, что тесты выполняются верно (How to Ensure Tests Execute Correctly)

### 5.1. Проверка аннотаций функций

ВСЕ функции должны иметь аннотации:

```bash
# @type:        Source | Filter | Transformer | Orchestrator | Validator | Sink
# @description: Краткое описание физики действия
# @stdin:       Формат входящих данных (например, NUL-separated paths (path\0))
# @stdout:      Формат выходящих данных
# @exit_code:   0 - успех
#               2 - намеренная отмена пользователем (SIGINT-like)
#               >0 - ошибка (кроме 2)
```

**Проверка:**

- Убедитесь, что каждая функция имеет все 5 аннотаций
- Убедитесь, что `@type` соответствует действительному типу функции
- Убедитесь, что `@description` точно описывает, что делает функция
- Убедитесь, что `@stdin` и `@stdout` точно описывают форматы данных
- Убедитесь, что `@exit_code` перечисляет все возможные коды возврата

### 5.2. Проверка NUL-разделителей

При работе со списками используйте NUL-разделитель (`\0`):

```bash
# ✅ ПРАВИЛЬНО - используем NUL-разделитель
printf '%s\0' "file1" "file2" "file3" | while IFS= read -r -d '' file; do
    echo "Processing: $file"
done

# ✅ ПРАВИЛЬНО - используем mapfile с -d ''
mapfile -d '' -t files < <(printf '%s\0' "file1" "file2" "file3")
for file in "${files[@]}"; do
    echo "Processing: $file"
done

# ❌ НЕПРАВИЛЬНО - используем newline-разделитель (не работает с путями с пробелами)
echo -e "file1\nfile2\nfile3" | while IFS= read -r file; do
    echo "Processing: $file"
done
```

**Объяснение:**

- NUL-разделитель (`\0`) — единственный надежный способ передачи данных в пайплайнах
- Newline-разделитель не работает с путями, содержащими пробелы или переносы строк
- Используйте `mapfile -d ''` для чтения NUL-разделенных списков

### 5.3. Проверка обработки ошибок

Используйте `set -euo pipefail` в начале скрипта:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Проверяйте exit codes всех команд:**

```bash
# ✅ ПРАВИЛЬНО - проверяем exit code
command || return 1

# ❌ НЕПРАВИЛЬНО - не проверяем exit code
command
```

**Используйте `|| true` для команд, где ошибки допустимы:**

```bash
# ✅ ПРАВИЛЬНО - ошибки допустимы
sudo systemctl restart sshd || true

# ❌ НЕПРАВИЛЬНО - ошибка прервет выполнение теста
sudo systemctl restart sshd
```

**Объяснение:**

- `set -euo pipefail` обеспечивает строгую обработку ошибок
- Проверка exit codes гарантирует, что ошибки не будут пропущены
- `|| true` используется для команд, где ошибки допустимы (например, при очистке)

### 5.4. Проверка изоляции тестов

**Setup должен подготавливать окружение:**

```bash
test::setup() {
    # Создаем резервные копии конфигураций
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bsss-test-backup
    
    # Устанавливаем тестовые значения
    echo "Port 22" | sudo tee /etc/ssh/sshd_config > /dev/null
}
```

**Cleanup должен восстанавливать окружение:**

```bash
test::cleanup() {
    # Восстанавливаем конфигурации
    if [[ -f /etc/ssh/sshd_config.bsss-test-backup ]]; then
        sudo mv /etc/ssh/sshd_config.bsss-test-backup /etc/ssh/sshd_config
    fi
    
    # Перезапускаем службы
    sudo systemctl restart sshd || true
}
```

**Проверка:**

- Убедитесь, что setup подготавливает чистое окружение
- Убедитесь, что cleanup полностью восстанавливает окружение
- Убедитесь, что тесты не влияют друг на друга

### 5.5. Проверка валидации

**ВСЕГДА валидируйте exit codes:**

```bash
if ! test::validate_exit_code "$exit_code" "0,2,3"; then
    test::cleanup
    return 1
fi
```

**ВСЕГДА валидируйте process lifecycle:**

```bash
if ! test::validate_lifecycle "$log_file"; then
    test::cleanup
    return 1
fi
```

**Добавляйте custom validation для проверки результатов:**

```bash
if ! test::custom_validate "$log_file"; then
    test::cleanup
    return 1
fi
```

**Проверка:**

- Убедитесь, что exit codes валидируются правильно
- Убедитесь, что process lifecycle валидируется
- Убедитесь, что custom validation проверяет ожидаемые результаты

---

## 6. Распространенные ошибки и как их избегать (Common Pitfalls and How to Avoid Them)

### 6.1. Использование piping вместо TEST_MODE

**❌ НЕПРАВИЛЬНО - piping не сработает!**

```bash
echo "Y" | sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
```

**Почему это не работает:**

Функция [`io::ask_value()`](../lib/user_confirmation.sh:24) читает ввод напрямую из `/dev/tty`, который обходит stdin. Piping через `|` не передаст ввод в функцию.

**✅ ПРАВИЛЬНО - используйте TEST_MODE**

```bash
export TEST_MODE="true"
sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
```

**Объяснение:**

- `TEST_MODE="true"` заставляет BSSS использовать тестовый режим
- В тестовом режиме интерактивные функции возвращают значения по умолчанию
- Это единственный надежный способ автоматизации тестов

### 6.2. Игнорирование exit code 2

**❌ НЕПРАВИЛЬНО - код 2 это не ошибка!**

```bash
if [[ "$exit_code" -ne 0 ]]; then
    test::cleanup
    return 1
fi
```

**Почему это не работает:**

Код 2 используется для обозначения отмены пользователем (например, через Ctrl+C). Это не ошибка, а нормальное поведение в некоторых сценариях.

**✅ ПРАВИЛЬНО - валидируйте код 2 как валидный**

```bash
if ! test::validate_exit_code "$exit_code" "0,2,3"; then
    test::cleanup
    return 1
fi
```

**Объяснение:**

- Код 2 — это намеренная отмена пользователем
- Код 3 — это успешный откат в сценариях rollback
- Эти коды должны валидироваться как успешные результаты

### 6.3. Отсутствие setup/cleanup

**❌ НЕПРАВИЛЬНО - нет изоляции тестов**

```bash
test::run() {
    # Запуск теста без подготовки и очистки
    export TEST_MODE="true"
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        return 1
    fi
    
    return 0
}
```

**Почему это не работает:**

Без setup и cleanup тесты не изолированы. Один тест может повлиять на другой, что приведет к непредсказуемым результатам.

**✅ ПРАВИЛЬНО - есть изоляция тестов**

```bash
test::setup() {
    # Подготовка окружения
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bsss-test-backup
}

test::cleanup() {
    # Очистка окружения
    if [[ -f /etc/ssh/sshd_config.bsss-test-backup ]]; then
        sudo mv /etc/ssh/sshd_config.bsss-test-backup /etc/ssh/sshd_config
    fi
}

test::run() {
    test::setup || return 1
    
    # Запуск теста
    export TEST_MODE="true"
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        test::cleanup
        return 1
    fi
    
    test::cleanup
    return 0
}
```

**Объяснение:**

- Setup подготавливает чистое окружение перед тестом
- Cleanup восстанавливает окружение после теста
- Это гарантирует изоляцию тестов

### 6.4. Отсутствие process lifecycle validation

**❌ НЕПРАВИЛЬНО - нет валидации процессов**

```bash
test::run() {
    # Запуск теста
    export TEST_MODE="true"
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        return 1
    fi
    
    # Нет валидации процессов!
    
    return 0
}
```

**Почему это не работает:**

Без process lifecycle validation тест может пройти, но система останется в нестабильном состоянии. Orphaned процессы могут продолжать работать и потреблять ресурсы.

**✅ ПРАВИЛЬНО - есть валидация процессов**

```bash
test::run() {
    # Запуск теста
    export TEST_MODE="true"
    sudo bash "${PROJECT_ROOT}/local-runner.sh" -t
    exit_code=$?
    
    if ! test::validate_exit_code "$exit_code" "0,2,3"; then
        return 1
    fi
    
    # Валидация процессов
    if ! test::validate_lifecycle "$log_file"; then
        return 1
    fi
    
    return 0
}
```

**Объяснение:**

- Process lifecycle validation обнаруживает orphaned процессы
- Это критично для обнаружения утечек ресурсов
- Без этой проверки тест может пройти, но система останется нестабильной

### 6.5. Чтение файлов без проверки

**❌ НЕПРАВИЛЬНО - может не сработать**

```bash
log_content=$(cat "$log_file")
```

**Почему это не работает:**

Если файл не существует, команда `cat` завершится с ошибкой, и из-за `set -euo pipefail` выполнение теста прервется.

**✅ ПРАВИЛЬНО - проверяйте существование файла**

```bash
if [[ ! -f "$log_file" ]]; then
    test::log_fail "Validation" "Log file not found: $log_file"
    return 1
fi
log_content=$(cat "$log_file")
```

**Объяснение:**

- Проверка существования файла предотвращает ошибки
- Это делает тест более надежным
- Ошибка обрабатывается явно с понятным сообщением

---

## 7. Примеры использования (Usage Examples)

### 7.1. Запуск всех тестов

```bash
sudo bash tests/test-runner.sh
```

**Результат:**

- Запускаются все тестовые сценарии из [`tests/scenarios/`](scenarios/)
- Отображается сводка результатов
- Логи сохраняются в `/tmp/bsss-tests/logs/`

### 7.2. Запуск конкретного теста

```bash
sudo bash tests/test-runner.sh --scenario ssh-success
```

**Результат:**

- Запускается только тест `ssh-success`
- Отображается детальный результат этого теста
- Логи сохраняются в `/tmp/bsss-tests/logs/`

### 7.3. Запуск с verbose выводом

```bash
sudo bash tests/test-runner.sh --verbose
```

**Результат:**

- Запускаются все тесты с детальным выводом
- Отображается дополнительная информация о каждом шаге
- Полезно для отладки

### 7.4. Запуск с очисткой логов

```bash
sudo bash tests/test-runner.sh --cleanup
```

**Результат:**

- Запускаются все тесты
- После выполнения удаляются все логи
- Полезно для очистки после тестов

### 7.5. Очистка состояния системы перед тестами

```bash
sudo bash tests/test-runner.sh --clean-state
```

**Результат:**

- Очищается состояние системы перед тестами
- Удаляются временные файлы
- Восстанавливаются конфигурации
- Полезно перед запуском тестов

---

## 8. Отладка тестов (Debugging Tests)

### 8.1. Просмотр логов

Логи сохраняются в `/tmp/bsss-tests/logs/`:

```bash
# Просмотр списка логов
ls -la /tmp/bsss-tests/logs/

# Просмотр конкретного лога
cat /tmp/bsss-tests/logs/ssh-success-20260121_123456.log

# Просмотр лога в реальном времени
tail -f /tmp/bsss-tests/logs/ssh-success-20260121_123456.log
```

### 8.2. Запуск с verbose режимом

```bash
# Добавьте --verbose для детального вывода
sudo bash tests/test-runner.sh --verbose
```

**Результат:**

- Отображается дополнительная информация о каждом шаге
- Полезно для понимания, что происходит внутри теста

### 8.3. Проверка конкретного теста

```bash
# Запустите только один тест для отладки
sudo bash tests/test-runner.sh --scenario ssh-success
```

**Результат:**

- Запускается только один тест
- Фокус на конкретном тесте упрощает отладку

### 8.4. Ручная проверка

```bash
# Запустите тест вручную для отладки
cd tests/scenarios
source ./ssh-success.sh
test::run
```

**Результат:**

- Тест запускается напрямую без test-runner
- Полный контроль над выполнением
- Можно добавлять `set -x` для трассировки выполнения

### 8.5. Использование set -x для трассировки

```bash
test::run() {
    set -x  # Включаем трассировку
    
    # Код теста
    
    set +x  # Выключаем трассировку
}
```

**Результат:**

- Отображается каждая выполняемая команда
- Полезно для понимания потока выполнения

---

## 9. Ресурсы и ссылки (Resources and References)

### Основная документация

- [`testing-architecture-prd.md`](../plans/testing-architecture-prd.md) — Полная спецификация тестовой архитектуры
- [`testing-implementation-summary.md`](../plans/testing-implementation-summary.md) — Сводка реализации

### Шаблоны и примеры

- [`template.sh`](scenarios/template.sh) — Шаблон тестового сценария
- [`ssh-success.sh`](scenarios/ssh-success.sh) — Пример успешного теста SSH
- [`ssh-rollback.sh`](scenarios/ssh-rollback.sh) — Пример теста rollback SSH
- [`ufw-enable.sh`](scenarios/ufw-enable.sh) — Пример теста UFW

### Библиотеки тестов

- [`lib/test-logging.sh`](lib/test-logging.sh) — Библиотека логирования тестов
- [`lib/test-runner.sh`](lib/test-runner.sh) — Движок выполнения тестов
- [`lib/test-parser.sh`](lib/test-parser.sh) — Парсер и валидатор логов

### Стандарты кодирования

- [`AGENTS.md`](../AGENTS.md) — Стандарты кодирования BSSS
- [`function_map.txt`](../function_map.txt) — Карта функций проекта

### Основной проект

- [`local-runner.sh`](../local-runner.sh) — Основной runner BSSS
- [`lib/`](../lib/) — Основные библиотеки проекта
- [`modules/`](../modules/) — Модули проекта

---

## Заключение

Это руководство предоставляет исчерпывающую информацию о работе с тестовой фреймворкой BSSS. Следуя этим рекомендациям, вы сможете:

- Создавать надежные и изолированные тесты
- Избегать распространенных ошибок
- Эффективно отлаживать тесты
- Расширять тестовую фреймворку

Помните: **качество тестов — это качество продукта**. Инвестируйте время в создание качественных тестов, и это окупится в будущем.

---

**Последнее обновление:** 2026-01-21
