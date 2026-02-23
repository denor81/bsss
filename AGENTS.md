# Манифест проектирования BSSS для агентов

## Изменения с последнего релиза

- **Разделение потоков вывода**: Логи (FD3) отделены от ошибок bash (FD2)
- **Перехват ошибок bash**: Автоматическое логирование ошибок bash через `log::bash::error()`
- **Полный откат из меню**: Новый модуль `full-rollback-modify.sh` с фоновым watchdog-процессом
- **Механизм rollback**: Фоновый процесс `utils/rollback.sh` с сигналами USR1/USR2 и FIFO-коммуникацией
- **GPG верификация**: Обязательная проверка подписи в `oneline-runner.sh`
- **I18n реорганизация**: Переводы разбиты по доменам (ssh.sh, system.sh, ufw.sh)

## 1. Команды разработки

### Тестирование
```bash
bash lib/i18n/.tests/run.sh                    # Все тесты
bash lib/i18n/.tests/test_translations.sh      # Одиночный тест
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
```

## 2. Архитектура

### Потоковая архитектура (Pipeline-first)
- Данные текут через пайпы, минимизируйте переменные
- Используйте NUL-разделители (\0) для передачи данных
- stdout (FD 1): чистые данные для следующего звена
- stderr (FD 2): ошибки bash (перехватываются через `log::bash::error()`)
- FD 3: логи приложения (все `log_*` функции)
- В `main.sh`: FD3 привязан к терминалу, FD2 перенаправлен в перехватчик

### Функциональные типы
- **Source**: Генерирует поток (printf, find)
- **Filter**: Принимает stdin, отдает stdout (gawk, sed, grep)
- **Validator**: Проверяет условия, возвращает код (0=истина, 1=ложь)
- **Orchestrator**: Управляет логикой запуска других функций
- **Sink**: Потребляет поток (запись в файл, выполнение команды)

### Система логирования
- **Логи приложения**: Выводятся в FD3 через `log_*` функции
- **Ошибки bash**: Автоматически перехватываются в FD2 и логируются через `log::bash::error()`
- **Перехватчик**: В `main.sh` через `exec 2> >(while read -r line; do log::bash::error "$line"; done)`
- **Вывод в файл**: `log::to_file` с timestamp в `$CURRENT_LOG_SYMLINK`
- **Вывод в journal**: `log::to_journal` для systemd journal
- **Логи пользователя**: `read` с перенаправлением `2>&3` для изоляции от ошибок bash

## 3. Контракт функции

Обязательна аннотация перед каждой функцией:
Важно использовать корректную табуляцию для форматирования контракта
```bash
# @type:        Source | Filter | Validator | Orchestrator | Sink
# @description: Краткое описание
# @params:      Опциональный пункт. В случае если функция принимает параметры указать их каждый с новой строки с указанием ожидаемого типа обязательно с ожидаемым завершающим символом.
#               rollback_type Тип отката (string\n)
#               main_script_pid PID основного скрипта (num\0)
#               watchdog_fifo FIFO для коммуникации (path) нет завершающего символа
# @stdin:       Формат входных данных (например, port\0) обязательно указывать ожидаемый завершающий символ
# @stdout:      Формат выходных данных (например, port\0) обязательно указывать ожидаемый завершающий символ
# @exit_code:   0 успех
#               1 критическая ошибка
#               2 отмена пользователем
#               3 успешно завершен откатом
#               4 требуется предварительная настройка
#               $? другие не определенные ошибки
```

## 4. Коды возврата

| Код | Категория |
|-----|-----------|
| 0   | SUCCESS |
| 2   | USER_CANCEL |
| 3   | ROLLBACK |
| 4   | PRE_CONFIG_REQUIRED |
| 130 | USER_CANCEL (SIGINT) |
| 1, >4 | CRITICAL |

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

## 6. Меню и модули

**Формат файла модуля:** `<domain>-<type>.sh` (os-check.sh, ssh-port-modify.sh)
**Шаблон модуля:** shebang + strict mode + sourcing (vars, logging, i18n)
**Шаблон меню:** отображение → выбор → диспетчеризация через `log_info_simple_tab`, `io::ask_value`, `case`

**Добавление модуля:**
1. Создайте файл в `modules/` с суффиксом `-check.sh` или `-modify.sh`
2. Добавьте перевод в `lib/i18n/ru/common.sh` (формат: `module.<domain>.name`)
3. Обновите `main.sh` (добавьте в `run_check()` или `run_modify()`)

## 7. Переиспользование кода

- Общие хелперы → `modules/helpers/common.sh`
- SSH-хелперы → `modules/helpers/ssh-port.sh`
- Предпочитайте композицию через пайплайны

### Инструменты
- gawk: обязательная зависимость для NUL-разделителей
- Синтаксис: `read -r -d ''`, `mapfile -d ''`, `sort -z`, `xargs -0`, `gawk ORS="\0"`
- Пути из vars.conf: без завершающего слеша, не используйте `${var%/}`

## 8. Rollback механизм

- **Watchdog**: Фоновый процесс (`utils/rollback.sh`) с таймером автоматического отката
- **Сигналы**: SIGUSR1 (остановить таймер), SIGUSR2 (немедленный откат)
- **FIFO**: Интерпроцессная коммуникация через именованные каналы
- **Типы отката**: `ssh`, `ufw`, `permissions`, `full`

```bash
WATCHDOG_PID=$(rollback::orchestrator::watchdog_start "ssh" "quiet")
rollback::orchestrator::watchdog_stop
```

**Резилиентность**: Игнорирует SIGPIPE/INT/TERM, использует `|| true`

## 9. Архитектурные принципы

- **Идемпотентность**: Повторный запуск не ломает систему, используйте `# Generated by BSSS`
- **Безопасность**: ПОЛНЫЙ ЗАПРЕТ eval; GPG верификация в oneline-runner
- **Выживаемость**: Используйте `|| true` для гашения ожидаемых ошибок
- **Робастность**: Пайплайны должны завершаться с кодом 0

## 10. I18n

**Структура**: `lib/i18n/<lang>/common.sh` - общие переводы

**Использование**:
```bash
log_info "$(_ "key" "arg1" "arg2")"
log_info_simple_tab "$(_ "no_translate" "/path")"  # Без перевода
```

**Логирование команд**: `log_info "$(_ "common.log_command" "systemctl restart ssh")"`
