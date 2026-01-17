# Отчет о тестировании логики скриптов BSSS

## Дата: 2026-01-17
## Цель: Проверка корректности ответов, логического поведения, кодов возврата и логов без внесения изменений

---

## Сводка результатов

| Категория | Статус | Количество проблем |
|-----------|--------|-------------------|
| Обработка SIGINT (^C) | ✅ КОРРЕКТНО | 0 |
| Логи запуска/остановки | ✅ КОРРЕКТНО | 0 |
| Коды возврата при отмене через confirm_action | ❌ КРИТИЧНО | 3 |
| Коды возврата при выборе "0" в меню | ❌ КРИТИЧНО | 1 |
| Сообщения о завершении | ⚠️ СРЕДНЕ | 3 |

---

## Детальный анализ

### 1. Обработка SIGINT (^C)

**Статус: ✅ КОРРЕКТНО**

**Анализ:**
- Все модули имеют `trap log_stop EXIT`
- При нажатии ^C срабатывает trap EXIT → вызывается `log_stop`
- Скрипт завершается с кодом 130
- Родительский скрипт (`bsss-main.sh`) корректно обрабатывает код 130 в case (строка 124)

**Проверка по логам:**
```
[?] [04-ssh-port-modify.sh] Введите новый SSH порт [1-65535, Enter для 30774]: ^C
[ ] [04-ssh-port-modify.sh]>>stop>>[PID: 40201]
[ ] [bsss-main.sh]>>stop>>[PID: 40124]
```
✅ Лог остановки присутствует в обоих модулях

```
[?] [05-ufw-modify.sh] Выберите действие [0-1]: ^C
[ ] [05-ufw-modify.sh]>>stop>>[PID: 40301]
[ ] [bsss-main.sh]>>stop>>[PID: 40224]
```
✅ Лог остановки присутствует в обоих модулях

```
[?] [02-update-system.sh] Обновить системные пакеты? [apt-get update && apt-get upgrade -y] [Y/n]: ^C
[ ] [02-update-system.sh]>>stop>>[PID: 40407]
[ ] [bsss-main.sh]>>stop>>[PID: 40327]
```
✅ Лог остановки присутствует в обоих модулях

---

### 2. Логи запуска/остановки

**Статус: ✅ КОРРЕКТНО**

**Анализ:**
- Каждый модуль вызывает `log_start` в начале функции `main()`
- Каждый модуль имеет `trap log_stop EXIT`
- Это гарантирует, что `log_stop` будет вызван при любом способе завершения

**Проверка по логам:**
Все модули корректно выводят:
- `>>start>>[PID: ...]` при запуске
- `>>stop>>[PID: ...]` при завершении

---

### 3. Коды возврата при отмене через confirm_action

**Статус: ❌ КРИТИЧНО**

**Проблема:** Когда пользователь отвечает "n" на `io::confirm_action`, модуль возвращает код 0 вместо кода 2.

**Пример из логов:**
```
[?] [05-ufw-modify.sh] Изменить состояние UFW? [Y/n]: n
[ ] [05-ufw-modify.sh]>>stop>>[PID: 40494]
[ ] [bsss-main.sh] Модуль успешно завершен [Code: 0]
```
❌ Должно быть: "Модуль завершен пользователем [Code: 2]"

```
[?] [02-update-system.sh] Обновить системные пакеты? [apt-get update && apt-get upgrade -y] [Y/n]: n
[ ] [02-update-system.sh]>>stop>>[PID: 40520]
[ ] [bsss-main.sh] Модуль успешно завершен [Code: 0]
```
❌ Должно быть: "Модуль завершен пользователем [Code: 2]"

**Корневая причина:**

В файлах модулей (`02-update-system.sh`, `04-ssh-port-modify.sh`, `05-ufw-modify.sh`):

```bash
main() {
    log_start
    
    if io::confirm_action "..."; then
        # логика модуля
    fi
}
```

Когда `io::confirm_action` возвращает код 2 (ответ "n"):
- Условие `if` ложно (код 2 != 0)
- Блок `then` не выполняется
- Функция `main` завершается без явного `return`
- Код возврата функции становится 0 (последняя выполненная команда - это проверка `if`)

**Затронутые файлы:**
1. [`modules/02-update-system.sh`](modules/02-update-system.sh:67-72)
2. [`modules/04-ssh-port-modify.sh`](modules/04-ssh-port-modify.sh:109-114)
3. [`modules/05-ufw-modify.sh`](modules/05-ufw-modify.sh:38-43)

**Решение:**
```bash
main() {
    log_start
    
    if io::confirm_action "..."; then
        # логика модуля
    else
        return 2  # Явный возврат кода отмены
    fi
}
```

---

### 4. Коды возврата при выборе "0" в меню UFW

**Статус: ❌ КРИТИЧНО**

**Проблема:** В [`modules/05-ufw-modify.sh`](modules/05-ufw-modify.sh:18-30) код возврата от `orchestrator::run_ufw_module` не передается в функцию `main`.

**Анализ кода:**

```bash
orchestrator::run_ufw_module() {
    # вернет код 2 при выходе 0 [ufw::select_action->io::ask_value->return 2]
    if ufw::get_menu_items | tee >(ufw::display_menu) | ufw::select_action | ufw::execute_action; then
        log_success "Успешно [Code: $?]"
    else
        local exit_code=$?
        case "$exit_code" in
            2) log_info "Выход [Code: $exit_code]"; return "$exit_code" ;;
            *) log_error "Сбой в цепочке UFW [Code: $exit_code]"; return "$exit_code" ;;
        esac
    fi
}

main() {
    log_start

    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::run_ufw_module  # ← Код возврата игнорируется!
    fi
}
```

Когда пользователь выбирает "0" в меню UFW:
1. `ufw::select_action` возвращает код 2 (из-за `cancel_keyword="0"` в [`modules/05-ufw-helpers.sh:71`](modules/05-ufw-helpers.sh:71))
2. Пайплайн завершается с кодом 2
3. `orchestrator::run_ufw_module` входит в else, логирует "Выход [Code: 2]" и возвращает 2
4. ❌ Но `main` не возвращает этот код! Функция завершается с кодом 0.

**Решение:**
```bash
main() {
    log_start

    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::run_ufw_module || return $?
    fi
}
```

---

### 5. Сообщения о завершении

**Статус: ⚠️ СРЕДНЕ**

**Проблема:** В `bsss-main.sh` сообщение "Модуль успешно завершен" выводится при коде 0, но код 0 может быть как при успешном выполнении, так и при отмене пользователем через confirm_action.

**Код в [`bsss-main.sh:122-126`](bsss-main.sh:122-126):**
```bash
case "$exit_code" in
    0) log_info "Модуль успешно завершен [Code: $exit_code]" ;;
    2|130) log_info "Модуль завершен пользователем [Code: $exit_code]" ;;
    *) log_error "Ошибка в модуле [$selected_module] [Code: $exit_code]" ;;
esac
```

**Проблема:** После исправления проблем #3 и #4 это сообщение станет корректным, но сейчас оно вводит в заблуждение.

---

## Рекомендации по исправлению

### Приоритет 1 (Критично): Исправить коды возврата в модулях

#### 1.1. [`modules/02-update-system.sh`](modules/02-update-system.sh:67-72)

**Текущий код:**
```bash
main() {
    log_start
    
    if io::confirm_action "Обновить системные пакеты? [apt-get update && apt-get upgrade -y]"; then
        sys::update_system
    fi
}
```

**Исправленный код:**
```bash
main() {
    log_start
    
    if io::confirm_action "Обновить системные пакеты? [apt-get update && apt-get upgrade -y]"; then
        sys::update_system
    else
        return 2
    fi
}
```

#### 1.2. [`modules/04-ssh-port-modify.sh`](modules/04-ssh-port-modify.sh:109-114)

**Текущий код:**
```bash
main() {
    log_start
    
    if io::confirm_action "Изменить конфигурацию SSH порта?"; then
        orchestrator::dispatch_logic
    fi
}
```

**Исправленный код:**
```bash
main() {
    log_start
    
    if io::confirm_action "Изменить конфигурацию SSH порта?"; then
        orchestrator::dispatch_logic
    else
        return 2
    fi
}
```

#### 1.3. [`modules/05-ufw-modify.sh`](modules/05-ufw-modify.sh:38-43)

**Текущий код:**
```bash
main() {
    log_start

    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::run_ufw_module
    fi
}
```

**Исправленный код:**
```bash
main() {
    log_start

    if io::confirm_action "Изменить состояние UFW?"; then
        orchestrator::run_ufw_module || return $?
    else
        return 2
    fi
}
```

---

## Дополнительные наблюдения

### Некорректный ввод в меню

**Статус: ✅ КОРРЕКТНО**

**Пример из логов:**
```
[?] [bsss-main.sh] Выберите модуль [0-3]: ^[[A
[x] [bsss-main.sh] Ошибка ввода. Ожидается: 0-3
[?] [bsss-main.sh] Выберите модуль [0-3]: 
[x] [bsss-main.sh] Ошибка ввода. Ожидается: 0-3
```

Функция [`io::ask_value`](lib/user_confirmation.sh:19-36) корректно обрабатывает:
- Пустой ввод (не соответствует паттерну)
- Некорректные символы (например, стрелка вверх)
- Повторный запрос ввода до получения валидного значения

---

## Заключение

### Что работает корректно:
1. ✅ Обработка SIGINT (^C) - все модули корректно завершаются с логами остановки
2. ✅ Логи запуска/остановки - присутствуют во всех модулях
3. ✅ Валидация ввода в меню - некорректный ввод обрабатывается корректно
4. ✅ Обработка кода 130 в bsss-main.sh - SIGINT распознается как "завершен пользователем"

### Что требует исправления:
1. ❌ Коды возврата при отмене через confirm_action (3 файла)
2. ❌ Код возврата при выборе "0" в меню UFW (1 файл)

### Риск:
- Средний: Пользователь видит сообщение "Модуль успешно завершен" при отмене действия
- Низкий: Логика скриптов работает корректно, но сообщения вводят в заблуждение

### Рекомендация:
Исправить коды возврата во всех модулях modify для соблюдения стандарта BSSS (код 2 = отмена пользователем).
