# Манифест проектирования BSSS для агентов

## 1. Команды разработки

### Тестирование
```bash
# Запуск всех тестов i18n
bash lib/i18n/.tests/run.sh

# Запуск отдельного теста
bash lib/i18n/.tests/test_translations.sh        # Проверка синхронизации переводов
bash lib/i18n/.tests/test_missing_translations.sh # Проверка битых ссылок
bash lib/i18n/.tests/test_unused_translations.sh  # Проверка неиспользуемых переводов
bash lib/i18n/.tests/test_hardcoded_strings.sh    # Проверка захардкоженных строк
bash lib/i18n/.tests/test_line_counts.sh          # Проверка количества строк

# Запуск основного скрипта
./main.sh

# Запуск модуля напрямую
bash modules/ssh-port-modify.sh
```

### Линтинг и форматирование
```bash
# Линтинг (если установлен shellcheck)
shellcheck main.sh modules/*.sh lib/*.sh

# Форматирование (если установлен shfmt)
shfmt -w main.sh modules/*.sh lib/*.sh

# Генерация карты функций
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
# @exit_code:   0 - успех
#               2 - отмена пользователем (INFO, не прерывает цикл)
#               3 - rollback завершение (INFO)
#               4 - требуется предварительная настройка (INFO)
#               1, >4 - критическая ошибка (CRITICAL)
```

## 4. Коды возврата

| Код | Категория | Обработка в Runner |
|-----|-----------|-------------------|
| 0   | SUCCESS   | Информационное сообщение |
| 2,3,4,130 | INFO | Продолжение цикла |
| 1, >4 | CRITICAL | Ошибка с логированием |

## 5. Стандарты кода

### Именование функций
- Формат: `domain::subdomain::action` (максимум 3 уровня)
- Префиксы: `orchestrator::`, `ssh::`, `ufw::`, `io::`, `sys::`
- Примеры: `ssh::port::is_free`, `ufw::rule::delete_all_bsss`

### Файлы
- Исполняемые файлы: shebang + проверка в конце:
  ```bash
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
      main "$@"
  fi
  ```
- Файлы, подгружаемые через source: без shebang (lib/, хелперы)

### Стиль
- Отступы: 4 пробела (не табы)
- Используйте `readonly` для констант, `local` для временных переменных
- Строгий режим: `set -Eeuo pipefail`
- Все вызовы awk должны быть `gawk` (GNU Awk для NUL-разделителей)
- ЗАПРЕЩЕНО: `eval`, `mapfile -t` без `-d ''`

### Валидация
- Строгая проверка через регулярные выражения
- Порты: `"^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"`

## 6. I18n

- Перевод делается ДО вызова функции: `log_info "$(_ "key" "arg1" "arg2")"`
- Без перевода: `log_info_simple_tab "$(_ "no_translate" "/path/to/file")"`
- Добавление: ключ в `lib/i18n/ru/common.sh` (обязательно), использовать через `"$(_ "key")"`
- Формат ключей: `module.submodule.action.message_type`

## 7. Меню

Используйте шаблон из `docs/menu/MENU_TEMPLATE.md`: отображение → выбор → диспетчеризация через `log_info_simple_tab`, `io::ask_value` с `cancel_keyword "0"`, и `case` (без пункта 0).

**Главное меню (main.sh):** захардкожено в `runner::module::run_modify()`
**Шаблон модуля:**
```bash
# @type:        Orchestrator
# @description: Запускает модуль с интерактивным меню
domain::orchestrator::run_module() {
    log_info_simple_tab "1. $(_ "domain.menu.item_action1")"
    log_info_simple_tab "2. $(_ "domain.menu.item_action2")"
    log_info_simple_tab "0. $(_ "common.exit")"

    local menu_id
    menu_id=$(io::ask_value "$(_ "common.ask_select_action")" "" "^[0-2]$" "0-2" "0" | tr -d '\0') || return

    case "$menu_id" in
        1) domain::action_one ;;
        2) domain::action_two ;;
        *) log_error "$(_ "domain.error.invalid_menu_id" "$menu_id")"; return 1 ;;
    esac
}
```

## 8. Структура модулей

**Формат имени файла:** `<domain>-<type>.sh`
- `os-check.sh` - модуль проверки
- `ssh-port-modify.sh` - модуль изменения

**Заголовок модуля:**
```bash
#!/usr/bin/env bash
# Краткое описание модуля (без мета-тегов!)

set -Eeuo pipefail

readonly PROJECT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd)/.."

source "${PROJECT_ROOT}/lib/vars.conf"
source "${PROJECT_ROOT}/lib/logging.sh"
source "${PROJECT_ROOT}/lib/i18n/loader.sh"

# ... остальной код ...
```

**ВАЖНО:** НЕ используйте мета-теги `MODULE_ORDER`, `MODULE_TYPE`, `MODULE_NAME` - они удалены!

## 9. Добавление новых модулей

1. **Создайте файл** в `modules/` с правильным суффиксом (`-check.sh` или `-modify.sh`)
2. **Добавьте перевод** названия в `lib/i18n/ru/common.sh` (формат: `module.<domain>.name`)
3. **Обновите main.sh:**
   - Добавьте модуль в `runner::module::run_check()` (если check)
   - Добавьте модуль в `runner::module::run_modify()` (если modify)
4. **Используйте шаблон меню** из `docs/menu/MENU_TEMPLATE.md` для modify модулей

## 10. Переиспользование кода

- Проверяйте `function_map.txt` перед написанием нового кода
- Общие хелперы → `modules/helpers/common.sh`
- SSH-хелперы → `modules/helpers/ssh-port.sh`
- Предпочитайте композицию через пайплайны

## 11. Инструменты

- gawk: обязательная зависимость для NUL-разделителей
- Синтаксис: `read -r -d ''`, `mapfile -d ''`, `sort -z`, `xargs -0`, `gawk ORS="\0"`
- Пути из vars.conf: без завершающего слеша, не используйте `${var%/}`

## 12. Архитектурные принципы

- **Идемпотентность**: Повторный запуск не ломает систему, используйте `# Generated by BSSS`
- **Безопасность**: ПОЛНЫЙ ЗАПРЕТ eval
- **Выживаемость**: Используйте `|| true` для гашения ожидаемых ошибок (например, закрытые FIFO в rollback.sh)
- **Робастность**: Пайплайны должны завершаться с кодом 0

## 13. Универсальные переводы

`common.log_command`: логирование команд без описания
```bash
log_info "$(_ "common.log_command" "systemctl restart ssh")"
systemctl restart ssh >/dev/null 2>&1
```
