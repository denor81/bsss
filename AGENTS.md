# Манифест проектирования BSSS для агентов

## Изменения с последнего релиза

- **Полный откат из меню**: Новый модуль `full-rollback-modify.sh` с фоновым watchdog-процессом
- **Механизм rollback**: Фоновый процесс `utils/rollback.sh` с сигналами USR1/USR2 и FIFO-коммуникацией
- **GPG верификация**: Обязательная проверка подписи в `oneline-runner.sh`
- **I18n реорганизация**: Переводы разбиты по доменам (ssh.sh, system.sh, ufw.sh)
- **SSH socket совместимость**: Исправлено определение socket для Ubuntu 20+
- **Улучшенная обработка ошибок**: Единообразное логирование и коды возврата

## 1. Команды разработки

### Тестирование
```bash
bash lib/i18n/.tests/run.sh  # Все тесты
bash lib/i18n/.tests/test_translations.sh
bash lib/i18n/.tests/test_missing_translations.sh
bash lib/i18n/.tests/test_unused_translations.sh
bash lib/i18n/.tests/test_hardcoded_strings.sh

./main.sh
bash modules/ssh-port-modify.sh
bash modules/full-rollback-modify.sh
```

### Линтинг
```bash
shellcheck main.sh modules/*.sh lib/*.sh
shfmt -w main.sh modules/*.sh lib/*.sh
./utils/generate_function_map.sh
```

## 2. Архитектура

### Потоковая архитектура (Pipeline-first)
- Данные текут через пайпы, минимизируйте переменные
- Используйте NUL-разделители (\0) для передачи данных
- stdout (FD 1): чистые данные для следующего звена
- stderr (FD 2): логи, интерфейсы, подтверждения

### Функциональные типы
- **Source**: Генерирует поток (printf, find)
- **Filter**: Принимает stdin, отдает stdout (gawk, sed, grep)
- **Validator**: Проверяет условия, возвращает код (0=истина, 1=ложь)
- **Orchestrator**: Управляет логикой запуска других функций
- **Sink**: Потребляет поток (запись в файл, выполнение команды)

## 3. Контракт функции

Обязательна аннотация перед каждой функцией:

```bash
# @type:        Source | Filter | Validator | Orchestrator | Sink
# @description: Краткое описание
# @stdin:       Формат входных данных (например, port\0)
# @stdout:      Формат выходных данных
# @exit_code:   0 - успех, 2-4 - INFO, 1,>4 - CRITICAL
```

## 4. Коды возврата

| Код | Категория | Обработка в Runner |
|-----|-----------|-------------------|
| 0   | SUCCESS   | Информационное сообщение |
| 2   | USER_CANCEL | Отмена пользователем |
| 3   | ROLLBACK | Завершение через rollback |
| 4   | PRE_CONFIG_REQUIRED | Требуется предварительная настройка |
| 130 | USER_CANCEL (SIGINT) | Прерывание пользователем |
| 1, >4 | CRITICAL | Критическая ошибка с логированием |

## 5. Стандарты кода

### Именование
- Функции: `domain::subdomain::action` (максимум 3 уровня)
- Префиксы: `orchestrator::`, `ssh::`, `ufw::`, `io::`, `sys::`
- Примеры: `ssh::port::is_free`, `ufw::rule::delete_all_bsss`

### Файлы
- Исполняемые: shebang + `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`
- Библиотеки: без shebang (lib/, хелперы)

### Стиль
- Отступы: 4 пробела (не табы)
- `readonly` для констант, `local` для временных переменных
- Строгий режим: `set -Eeuo pipefail`
- Используйте `gawk` (GNU Awk для NUL-разделителей)
- ЗАПРЕЩЕНО: `eval`, `mapfile -t` без `-d ''`

### Валидация
- Порты: `"^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"`

## 6. Меню

Используйте шаблон из `docs/menu/MENU_TEMPLATE.md`: отображение → выбор → диспетчеризация через `log_info_simple_tab`, `io::ask_value` с `cancel_keyword "0"`, и `case` (без пункта 0).

**Главное меню**: захардкожено в `runner::module::run_modify()`
**Шаблон модуля**:
```bash
# @type: Orchestrator
# @description: Запускает модуль с интерактивным меню
domain::orchestrator::run_module() {
    log_info_simple_tab "1. $(_ "domain.menu.item_action1")"
    log_info_simple_tab "0. $(_ "common.exit")"
    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-1]$" "0-1" "0" | tr -d '\0') || return
    case "$menu_id" in 1) domain::action_one ;; esac
}
```

## 8. Структура модулей

**Формат имени файла:** `<domain>-<type>.sh`
- `os-check.sh` - модуль проверки
- `ssh-port-modify.sh` - модуль изменения

**Заголовок модуля**:
```bash
#!/usr/bin/env bash
# Краткое описание модуля (без мета-тегов!)
set -Eeuo pipefail
readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" )" && pwd)/.."
source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"
```

**ВАЖНО:** НЕ используйте мета-теги `MODULE_ORDER`, `MODULE_TYPE`, `MODULE_NAME` - они удалены!

## 8. Добавление новых модулей

1. Создайте файл в `modules/` с суффиксом `-check.sh` или `-modify.sh`
2. Добавьте перевод названия в `lib/i18n/ru/common.sh` (формат: `module.<domain>.name`)
3. Обновите `main.sh` (добавьте в `run_check()` или `run_modify()`)
4. Используйте шаблон меню из `docs/menu/MENU_TEMPLATE.md`

## 9. Переиспользование кода

- Проверяйте `function_map.txt` перед написанием нового кода
- Общие хелперы → `modules/helpers/common.sh`
- SSH-хелперы → `modules/helpers/ssh-port.sh`
- Предпочитайте композицию через пайплайны

### Инструменты
- gawk: обязательная зависимость для NUL-разделителей
- Синтаксис: `read -r -d ''`, `mapfile -d ''`, `sort -z`, `xargs -0`, `gawk ORS="\0"`
- Пути из vars.conf: без завершающего слеша, не используйте `${var%/}`

## 10. Rollback механизм

- **Watchdog**: Фоновый процесс (`utils/rollback.sh`) с таймером автоматического отката
- **Сигналы**: SIGUSR1 (остановить таймер), SIGUSR2 (немедленный откат)
- **FIFO**: Интерпроцессная коммуникация через именованные каналы
- **Типы отката**: `ssh`, `ufw`, `permissions`, `full`

```bash
# Запуск в модуле с таймером
WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ssh" "quiet")
rollback::orchestrator::watchdog_stop

# Полный откат из меню
ssh::orchestrator::trigger_immediate_rollback
trap common::rollback::stop_script_by_rollback_timer SIGUSR1
```

**Резилиентность**: Игнорирует SIGPIPE/INT/TERM, использует `|| true` для безопасного завершения

## 11. Архитектурные принципы

- **Идемпотентность**: Повторный запуск не ломает систему, используйте `# Generated by BSSS`
- **Безопасность**: ПОЛНЫЙ ЗАПРЕТ eval; GPG верификация в oneline-runner
- **Выживаемость**: Используйте `|| true` для гашения ожидаемых ошибок (например, закрытые FIFO в rollback.sh)
- **Робастность**: Пайплайны должны завершаться с кодом 0
- **Потоковая обработка**: Предпочитайте пайпы вместо временных переменных

## 12. I18n

### Структура
- `lib/i18n/<lang>/common.sh` - общие переводы

### Использование
```bash
# Добавьте ключ в BOTH ru и en файлы
log_info "$(_ "key" "arg1" "arg2")"
log_info_simple_tab "$(_ "no_translate" "/path")"  # Без перевода
```

`common.log_command`: логирование команд без описания
```bash
log_info "$(_ "common.log_command" "systemctl restart ssh")"
systemctl restart ssh >/dev/null 2>&1
```
