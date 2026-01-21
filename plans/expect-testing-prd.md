# BSSS Expect Testing PRD

## 1. Введение

### 1.1 Обзор

**Цель:** Создать автоматизированную систему тестирования для BSSS (Bash System Security Setup) с использованием Expect для взаимодействия с интерактивным меню без модификации производственного кода.

### 1.2 Почему Expect вместо предыдущего подхода

**Проблемы предыдущего подхода (testing-architecture-prd.md):**

1. **Требует модификации производственного кода:**
   - Необходимо изменить `lib/logging.sh` для добавления файлового логирования
   - Необходимо изменить `lib/user_confirmation.sh` для добавления тестового режима
   - Необходимо изменить `lib/vars.conf` для добавления переменных тестирования
   - Необходимо изменить `local-runner.sh` для добавления флага тестирования

2. **Проблема с TTY:**
   - `io::ask_value()` читает из `/dev/tty` (строка 24 в `lib/user_confirmation.sh`), что обходить stdin pipes
   - Пайпинг ввода через `echo "input" | command` не работает
   - Требуется сложная модификация функций для поддержки TEST_MODE

3. **Сложность FD3 логирования:**
   - Rollback процесс логирует в FD3, не FD2
   - Требуется захват дополнительных файловых дескрипторов
   - Усложняет архитектуру тестирования

4. **Высокий риск регрессий:**
   - Изменения в критических библиотеках (logging, user_confirmation)
   - Возможность нарушения существующей функциональности
   - Сложность тестирования изменений в самих библиотеках

**Преимущества Expect:**

1. **Без модификации производственного кода:**
   - Тесты взаимодействуют с существующим меню как обычный пользователь
   - Никаких изменений в logging.sh, user_confirmation.sh, vars.conf
   - Никаких изменений в модулях или main скрипте

2. **Прямое взаимодействие с TTY:**
   - Expect специально разработан для автоматизации интерактивных программ
   - Работает напрямую с терминальным вводом/выводом
   - Может отправлять ввод и ожидать определенные паттерны в выводе

3. **Простой захват stderr:**
   - Expect может перенаправлять stderr в файл для анализа
   - Все логи (включая log_start/log_stop) попадают в один поток
   - Простая парсинга маркеров `>>start>>` и `>>stop>>`

4. **Минимальный риск:**
   - Тесты изолированы от производственного кода
   - Ошибки в тестах не влияют на систему
   - Легко отключить тесты без изменения кода

### 1.3 Контекст проекта

**Текущее состояние логирования:**

- Все логи выводятся в stderr (FD2)
- `log_start()` выводит: `[MODULE_NAME]>>start>>[PID: XXXXX]`
- `log_stop()` выводит: пустая строка + `[MODULE_NAME]>>stop>>[PID: XXXXX]`
- bsss-main.sh:140 вызывает `log_start` в начале выполнения
- bsss-main.sh:16 устанавливает `trap log_stop EXIT` для автоматического вызова при завершении

**Структура меню (bsss-main.sh):**

```
0   - Выход из меню настройки
00  - Проверка системы (запуск модулей check)
1-N - Запуск модулей modify (SSH, UFW и т.д.)
```

**Точки логирования:**

- bsss-main.sh:140 - `log_start` (начало выполнения)
- bsss-main.sh:16 - `trap log_stop EXIT` (завершение выполнения)
- Все модули modify вызывают свои собственные log_start/log_stop
- Rollback процессы (utils/rollback.sh) также логируют

---

## 2. Цели тестирования

### 2.1 Основные цели

1. **Тестирование взаимодействия с меню BSSS:**
   - Проверка навигации по всем веткам меню
   - Проверка корректности ввода ответов на вопросы
   - Проверка обработки некорректного ввода

2. **Проверка логирования процессов (log_start/log_stop):**
   - Для каждого сценария проверить наличие пары log_start/log_stop
   - Проверить соответствие PID в маркерах
   - Проверить порядок вызова (start должен быть до stop)

3. **Покрытие всех веток меню:**
   - Ветка 0: Выход из меню
   - Ветка 00: Проверка системы (модули check)
   - Ветки 1-N: Запуск модулей modify

### 2.2 Успешные критерии

- Все ветки меню протестированы
- Для каждого сценария проверено наличие log_start и log_stop
- Тесты автоматизированы и могут запускаться одной командой
- Тесты изолированы и не влияют друг на друга
- Тесты могут выполняться на виртуальной машине без риска для системы

---

## 3. Архитектура тестов на Expect

### 3.1 Общая архитектура

```
tests/expect/
├── lib/
│   ├── expect-helpers.exp      # Общие хелперы для Expect
│   ├── log-parser.exp          # Парсер логов для поиска маркеров
│   └── test-runner.exp         # Главный тест-раннер
├── scenarios/
│   ├── menu-exit.exp           # Тест выхода из меню (ветка 0)
│   ├── menu-check.exp          # Тест проверки системы (ветка 00)
│   ├── ssh-modify.exp          # Тест модуля SSH (ветка 1)
│   ├── ufw-modify.exp          # Тест модуля UFW (ветка 2)
│   └── ...                     # Другие сценарии
├── logs/                       # Директория для логов тестов
└── run-all.exp                 # Скрипт для запуска всех тестов
```

### 3.2 Как Expect взаимодействует с меню

**Принцип работы:**

1. Expect запускает BSSS через `spawn sudo bash bsss-main.sh`
2. Expect ожидает появления определенных паттернов в выводе (например, текст вопроса)
3. Expect отправляет ответ на вопрос (например, "0" для выхода)
4. Expect перехватывает весь вывод (stdout и stderr) в лог-файл
5. После завершения BSSS, Expect анализирует лог-файл для проверки маркеров log_start/log_stop

**Пример потока данных:**

```
Expect → (stdin) → BSSS (bsss-main.sh) → (stdout/stderr) → Лог-файл
                                      ↓
                              Анализ маркеров
                                      ↓
                              Результат теста
```

### 3.3 Перехват и анализ stderr

**Перенаправление stderr в Expect:**

Expect использует команду `log_file` для записи всего вывода в файл:

```tcl
# Запись всего вывода (stdout + stderr) в лог-файл
log_file -noappend $log_file

# Или раздельная запись (если нужно)
log_file -noappend -leaveopen $stdout_file
```

**Анализ маркеров log_start/log_stop:**

После завершения теста, Expect скрипт читает лог-файл и ищет маркеры:

```tcl
# Поиск маркеров в лог-файле
set fp [open $log_file r]
set content [read $fp]
close $fp

# Поиск всех маркеров >>start>>
set start_matches [regexp -all -inline {>>start>>\[PID:\s+(\d+)\]} $content]

# Поиск всех маркеров >>stop>>
set stop_matches [regexp -all -inline {>>stop>>\[PID:\s+(\d+)\]} $content]

# Проверка парности
if {[llength $start_matches] != [llength $stop_matches]} {
    puts "ERROR: Количество start и stop маркеров не совпадает"
    exit 1
}
```

### 3.4 Структура тестового сценария

**Каждый тестовый сценарий (Expect скрипт) включает:**

1. **Настройка:**
   - Определение имени теста
   - Создание лог-файла
   - Установка таймаутов

2. **Выполнение:**
   - Запуск BSSS через `spawn`
   - Последовательность ожиданий и отправки ответов
   - Захват вывода в лог-файл

3. **Валидация:**
   - Анализ лог-файла на наличие маркеров log_start/log_stop
   - Проверка соответствия PID
   - Проверка порядка маркеров

4. **Очистка:**
   - Закрытие лог-файла
   - Удаление временных файлов (опционально)
   - Возврат кода завершения

---

## 4. Сценарии тестирования

### 4.1 Сценарий 1: Выход из меню (ветка 0)

**Описание:** Проверка корректного выхода из меню без выполнения каких-либо действий.

**Действия в меню:**
1. Запуск BSSS
2. Ожидание появления меню модулей
3. Ввод "0" для выхода
4. Завершение работы

**Ожидаемые маркеры log_start/log_stop:**
- `[bsss-main.sh]>>start>>[PID: XXXXX]` - запуск bsss-main.sh
- `[bsss-main.sh]>>stop>>[PID: XXXXX]` - завершение bsss-main.sh

**Проверка в Expect:**
```tcl
# Ожидание меню модулей
expect {
    timeout { puts "ERROR: Timeout waiting for menu"; exit 1 }
    -re "Выберите модуль" { send "0\r" }
}

# Ожидание завершения
expect {
    timeout { puts "ERROR: Timeout waiting for exit"; exit 1 }
    eof { puts "BSSS exited successfully" }
}

# Анализ лог-файла
# Проверка наличия одной пары start/stop для bsss-main.sh
```

### 4.2 Сценарий 2: Проверка системы (ветка 00)

**Описание:** Запуск всех модулей типа check для проверки системы.

**Действия в меню:**
1. Запуск BSSS
2. Ожидание появления меню модулей
3. Ввод "00" для проверки системы
4. Возврат в главное меню
5. Ввод "0" для выхода

**Ожидаемые маркеры log_start/log_stop:**
- `[bsss-main.sh]>>start>>[PID: XXXXX]` - запуск bsss-main.sh
- `[01-os-check.sh]>>start>>[PID: YYYYY]` - запуск модуля OS check
- `[01-os-check.sh]>>stop>>[PID: YYYYY]` - завершение модуля OS check
- `[02-update-system.sh]>>start>>[PID: ZZZZZ]` - запуск модуля update system
- `[02-update-system.sh]>>stop>>[PID: ZZZZZ]` - завершение модуля update system
- `[03-sys-reload-check.sh]>>start>>[PID: WWWWW]` - запуск модуля sys reload check
- `[03-sys-reload-check.sh]>>stop>>[PID: WWWWW]` - завершение модуля sys reload check
- `[bsss-main.sh]>>stop>>[PID: XXXXX]` - завершение bsss-main.sh

**Проверка в Expect:**
```tcl
# Ожидание меню модулей
expect {
    timeout { puts "ERROR: Timeout waiting for menu"; exit 1 }
    -re "Выберите модуль" { send "00\r" }
}

# Ожидание завершения проверки и возврата в меню
expect {
    timeout { puts "ERROR: Timeout waiting for check completion"; exit 1 }
    -re "Выберите модуль" { send "0\r" }
}

# Ожидание завершения
expect {
    timeout { puts "ERROR: Timeout waiting for exit"; exit 1 }
    eof { puts "BSSS exited successfully" }
}

# Анализ лог-файла
# Проверка наличия пар start/stop для bsss-main.sh и всех модулей check
```

### 4.3 Сценарий 3: Модуль SSH (ветка 1)

**Описание:** Запуск модуля SSH для изменения порта.

**Действия в меню:**
1. Запуск BSSS
2. Ожидание появления меню модулей
3. Ввод "1" для выбора модуля SSH
4. Подтверждение изменения конфигурации SSH
5. Ввод нового порта (или Enter для дефолтного)
6. Подтверждение подключения
7. Возврат в главное меню
8. Ввод "0" для выхода

**Ожидаемые маркеры log_start/log_stop:**
- `[bsss-main.sh]>>start>>[PID: XXXXX]` - запуск bsss-main.sh
- `[04-ssh-port-modify.sh]>>start>>[PID: YYYYY]` - запуск модуля SSH
- `[04-ssh-port-modify.sh]>>stop>>[PID: YYYYY]` - завершение модуля SSH
- `[bsss-main.sh]>>stop>>[PID: XXXXX]` - завершение bsss-main.sh

**Примечание:** Rollback процесс также может логировать start/stop, если он запускается.

**Проверка в Expect:**
```tcl
# Ожидание меню модулей
expect {
    timeout { puts "ERROR: Timeout waiting for menu"; exit 1 }
    -re "Выберите модуль" { send "1\r" }
}

# Ожидание подтверждения изменения SSH
expect {
    timeout { puts "ERROR: Timeout waiting for SSH confirmation"; exit 1 }
    -re "Изменить конфигурацию SSH порта" { send "y\r" }
}

# Ожидание ввода порта
expect {
    timeout { puts "ERROR: Timeout waiting for port input"; exit 1 }
    -re "Введите новый SSH порт" { send "\r" }
}

# Ожидание подтверждения подключения
expect {
    timeout { puts "ERROR: Timeout waiting for connection confirmation"; exit 1 }
    -re "Подтвердите подключение" { send "connected\r" }
}

# Ожидание возврата в меню
expect {
    timeout { puts "ERROR: Timeout waiting for menu return"; exit 1 }
    -re "Выберите модуль" { send "0\r" }
}

# Ожидание завершения
expect {
    timeout { puts "ERROR: Timeout waiting for exit"; exit 1 }
    eof { puts "BSSS exited successfully" }
}

# Анализ лог-файла
# Проверка наличия пар start/stop для bsss-main.sh и модуля SSH
```

### 4.4 Сценарий 4: Модуль UFW (ветка 2)

**Описание:** Запуск модуля UFW для изменения состояния файрвола.

**Действия в меню:**
1. Запуск BSSS
2. Ожидание появления меню модулей
3. Ввод "2" для выбора модуля UFW
4. Подтверждение изменения состояния UFW
5. Выбор действия (enable/disable)
6. Подтверждение работы UFW
7. Возврат в главное меню
8. Ввод "0" для выхода

**Ожидаемые маркеры log_start/log_stop:**
- `[bsss-main.sh]>>start>>[PID: XXXXX]` - запуск bsss-main.sh
- `[05-ufw-modify.sh]>>start>>[PID: YYYYY]` - запуск модуля UFW
- `[05-ufw-modify.sh]>>stop>>[PID: YYYYY]` - завершение модуля UFW
- `[bsss-main.sh]>>stop>>[PID: XXXXX]` - завершение bsss-main.sh

**Проверка в Expect:**
```tcl
# Ожидание меню модулей
expect {
    timeout { puts "ERROR: Timeout waiting for menu"; exit 1 }
    -re "Выберите модуль" { send "2\r" }
}

# Ожидание подтверждения изменения UFW
expect {
    timeout { puts "ERROR: Timeout waiting for UFW confirmation"; exit 1 }
    -re "Изменить состояние UFW" { send "y\r" }
}

# Ожидание выбора действия
expect {
    timeout { puts "ERROR: Timeout waiting for action selection"; exit 1 }
    -re "Выберите действие" { send "0\r" }
}

# Ожидание подтверждения работы UFW
expect {
    timeout { puts "ERROR: Timeout waiting for UFW confirmation"; exit 1 }
    -re "Подтвердите работу UFW" { send "confirmed\r" }
}

# Ожидание возврата в меню
expect {
    timeout { puts "ERROR: Timeout waiting for menu return"; exit 1 }
    -re "Выберите модуль" { send "0\r" }
}

# Ожидание завершения
expect {
    timeout { puts "ERROR: Timeout waiting for exit"; exit 1 }
    eof { puts "BSSS exited successfully" }
}

# Анализ лог-файла
# Проверка наличия пар start/stop для bsss-main.sh и модуля UFW
```

### 4.5 Сценарий 5: Rollback (SSH timeout)

**Описание:** Проверка автоматического отката при таймауте подтверждения подключения.

**Действия в меню:**
1. Запуск BSSS
2. Ожидание появления меню модулей
3. Ввод "1" для выбора модуля SSH
4. Подтверждение изменения конфигурации SSH
5. Ввод нового порта (или Enter для дефолтного)
6. НЕ подтверждать подключение (ожидание таймаута)
7. Ожидание выполнения rollback
8. Возврат в главное меню
9. Ввод "0" для выхода

**Ожидаемые маркеры log_start/log_stop:**
- `[bsss-main.sh]>>start>>[PID: XXXXX]` - запуск bsss-main.sh
- `[04-ssh-port-modify.sh]>>start>>[PID: YYYYY]` - запуск модуля SSH
- `[04-ssh-port-modify.sh]>>stop>>[PID: YYYYY]` - завершение модуля SSH (с кодом 3)
- `[bsss-main.sh]>>stop>>[PID: XXXXX]` - завершение bsss-main.sh

**Примечание:** Rollback процесс также может логировать start/stop.

**Проверка в Expect:**
```tcl
# Ожидание меню модулей
expect {
    timeout { puts "ERROR: Timeout waiting for menu"; exit 1 }
    -re "Выберите модуль" { send "1\r" }
}

# Ожидание подтверждения изменения SSH
expect {
    timeout { puts "ERROR: Timeout waiting for SSH confirmation"; exit 1 }
    -re "Изменить конфигурацию SSH порта" { send "y\r" }
}

# Ожидание ввода порта
expect {
    timeout { puts "ERROR: Timeout waiting for port input"; exit 1 }
    -re "Введите новый SSH порт" { send "\r" }
}

# Ожидание таймаута подтверждения подключения (rollback)
expect {
    timeout { puts "INFO: Timeout occurred, rollback executed" }
    -re "Подтвердите подключение" { puts "ERROR: Should not see connection prompt"; exit 1 }
}

# Ожидание возврата в меню
expect {
    timeout { puts "ERROR: Timeout waiting for menu return"; exit 1 }
    -re "Выберите модуль" { send "0\r" }
}

# Ожидание завершения
expect {
    timeout { puts "ERROR: Timeout waiting for exit"; exit 1 }
    eof { puts "BSSS exited successfully" }
}

# Анализ лог-файла
# Проверка наличия пар start/stop для bsss-main.sh и модуля SSH
# Проверка наличия сообщений о rollback
```

---

## 5. Структура тестовых файлов

### 5.1 Расположение тестов

**Директория:** `tests/expect/`

**Структура:**
```
tests/expect/
├── lib/
│   ├── expect-helpers.exp      # Общие хелперы для Expect
│   ├── log-parser.exp          # Парсер логов для поиска маркеров
│   └── test-runner.exp         # Главный тест-раннер
├── scenarios/
│   ├── menu-exit.exp           # Тест выхода из меню (ветка 0)
│   ├── menu-check.exp          # Тест проверки системы (ветка 00)
│   ├── ssh-modify.exp          # Тест модуля SSH (ветка 1)
│   ├── ssh-rollback.exp        # Тест rollback SSH (таймаут)
│   ├── ufw-modify.exp          # Тест модуля UFW (ветка 2)
│   └── ufw-rollback.exp        # Тест rollback UFW (таймаут)
├── logs/                       # Директория для логов тестов
└── run-all.exp                 # Скрипт для запуска всех тестов
```

### 5.2 Именование файлов

**Формат:** `<module>-<scenario>.exp`

**Примеры:**
- `menu-exit.exp` - тест выхода из меню
- `menu-check.exp` - тест проверки системы
- `ssh-modify.exp` - тест изменения SSH порта
- `ssh-rollback.exp` - тест rollback SSH
- `ufw-modify.exp` - тест изменения UFW
- `ufw-rollback.exp` - тест rollback UFW

### 5.3 Общие хелперы для Expect

**Файл:** `tests/expect/lib/expect-helpers.exp`

**Функции:**

1. `start_bsss` - Запуск BSSS с логированием
2. `wait_for_prompt` - Ожидание появления меню
3. `send_input` - Отправка ввода с логированием
4. `wait_for_exit` - Ожидание завершения BSSS
5. `parse_log_file` - Парсинг лог-файла для поиска маркеров
6. `validate_lifecycle` - Проверка парности start/stop маркеров

**Пример использования:**
```tcl
source lib/expect-helpers.exp

# Запуск BSSS
set log_file [start_bsss]

# Ожидание меню
wait_for_prompt

# Отправка ввода
send_input "0"

# Ожидание завершения
wait_for_exit

# Валидация
validate_lifecycle $log_file
```

---

## 6. Инструменты и зависимости

### 6.1 Expect

**Версия:** Expect 5.45 или выше

**Установка:**
```bash
# Debian/Ubuntu
sudo apt-get install expect

# RHEL/CentOS
sudo yum install expect

# macOS
brew install expect
```

**Проверка установки:**
```bash
expect -version
```

### 6.2 Дополнительные утилиты

**Необходимые:**
- `bash` - для запуска BSSS
- `sudo` - для запуска BSSS с правами root
- `grep` - для поиска маркеров в лог-файлах
- `awk` - для парсинга логов
- `sed` - для обработки текста

**Опциональные:**
- `jq` - для обработки JSON (если будет использоваться JSON отчетность)
- `colorize` - для цветного вывода результатов тестов

### 6.3 Требования к окружению

**Виртуальная машина:**
- Ubuntu Linux (рекомендуется)
- Root/sudo доступ
- Минимум 2GB RAM
- Минимум 10GB дискового пространства

**Безопасность:**
- Тесты должны запускаться на изолированной виртуальной машине
- Тесты могут модифицировать системные настройки (SSH, UFW)
- После завершения тестов система должна быть возвращена в исходное состояние

---

## 7. План реализации по фазам

### 7.1 Фаза 1: Базовая инфраструктура Expect

**Цель:** Создать базовую инфраструктуру для запуска тестов.

**Задачи:**
1. Создать директорию `tests/expect/`
2. Создать файл `tests/expect/lib/expect-helpers.exp` с базовыми функциями
3. Создать файл `tests/expect/run-all.exp` для запуска всех тестов
4. Создать директорию `tests/expect/logs/` для логов тестов
5. Написать базовый тестовый сценарий `menu-exit.exp`

**Критерии успеха:**
- `expect tests/expect/scenarios/menu-exit.exp` успешно запускается
- Лог-файл создается в `tests/expect/logs/`
- Тест проверяет наличие маркеров `>>start>>` и `>>stop>>`
- Тест возвращает код 0 при успехе, 1 при неудаче

### 7.2 Фаза 2: Тестирование простых сценариев (выход)

**Цель:** Реализовать тест для выхода из меню.

**Задачи:**
1. Реализовать `menu-exit.exp` полностью
2. Добавить функцию `validate_lifecycle` в `expect-helpers.exp`
3. Добавить функцию `parse_log_file` в `expect-helpers.exp`
4. Протестировать сценарий выхода из меню

**Критерии успеха:**
- Тест `menu-exit.exp` проходит успешно
- Проверяется наличие одной пары start/stop для bsss-main.sh
- PID в маркерах start и stop совпадают
- Лог-файл содержит все ожидаемые маркеры

### 7.3 Фаза 3: Тестирование модулей check

**Цель:** Реализовать тест для проверки системы (ветка 00).

**Задачи:**
1. Реализовать `menu-check.exp`
2. Добавить функцию `validate_multiple_lifecycles` для проверки нескольких процессов
3. Протестировать сценарий проверки системы

**Критерии успеха:**
- Тест `menu-check.exp` проходит успешно
- Проверяются пары start/stop для bsss-main.sh и всех модулей check
- PID в маркерах start и stop совпадают для каждого процесса
- Лог-файл содержит все ожидаемые маркеры

### 7.4 Фаза 4: Тестирование модулей modify

**Цель:** Реализовать тесты для модулей modify (SSH, UFW).

**Задачи:**
1. Реализовать `ssh-modify.exp`
2. Реализовать `ufw-modify.exp`
3. Добавить обработку специфических вопросов для каждого модуля
4. Протестировать сценарии модулей modify

**Критерии успеха:**
- Тесты `ssh-modify.exp` и `ufw-modify.exp` проходят успешно
- Проверяются пары start/stop для bsss-main.sh и модулей modify
- PID в маркерах start и stop совпадают
- Лог-файлы содержат все ожидаемые маркеры

### 7.5 Фаза 5: Тестирование rollback сценариев

**Цель:** Реализовать тесты для rollback (таймауты).

**Задачи:**
1. Реализовать `ssh-rollback.exp`
2. Реализовать `ufw-rollback.exp`
3. Добавить обработку таймаутов в Expect
4. Протестировать сценарии rollback

**Критерии успеха:**
- Тесты `ssh-rollback.exp` и `ufw-rollback.exp` проходят успешно
- Проверяются пары start/stop для bsss-main.sh и модулей modify
- Проверяется наличие сообщений о rollback
- Лог-файлы содержат все ожидаемые маркеры

---

## 8. Примеры кода

### 8.1 Пример Expect скрипта для тестирования выхода из меню

**Файл:** `tests/expect/scenarios/menu-exit.exp`

```tcl
#!/usr/bin/env expect
# @description: Тест выхода из меню BSSS (ветка 0)
# @expected: Одна пара start/stop для bsss-main.sh

# Загрузка хелперов
source [file dirname $argv0]/../lib/expect-helpers.exp

# Настройка
set test_name "menu-exit"
set log_dir "tests/expect/logs"
set log_file "$log_dir/${test_name}.log"

# Создание директории для логов
file mkdir $log_dir

# Запуск BSSS
spawn sudo bash bsss-main.sh
set spawn_id $spawn_id

# Настройка логирования
log_file -noappend $log_file

# Установка таймаута
set timeout 30

# Ожидание меню модулей
expect {
    timeout {
        puts "ERROR: Timeout waiting for menu"
        exit 1
    }
    -re "Выберите модуль" {
        puts "INFO: Menu appeared, sending '0' to exit"
        send "0\r"
    }
}

# Ожидание завершения
expect {
    timeout {
        puts "ERROR: Timeout waiting for exit"
        exit 1
    }
    eof {
        puts "INFO: BSSS exited successfully"
    }
}

# Закрытие лог-файла
log_file

# Валидация логов
puts "INFO: Validating log file: $log_file"
if {![validate_lifecycle $log_file]} {
    puts "ERROR: Lifecycle validation failed"
    exit 1
}

puts "SUCCESS: Test passed"
exit 0
```

### 8.2 Пример проверки маркеров log_start/log_stop

**Функция в `tests/expect/lib/expect-helpers.exp`:**

```tcl
# @description: Проверка парности start/stop маркеров в лог-файле
# @params: log_file - путь к лог-файлу
# @return: 1 - успешно, 0 - неудача
proc validate_lifecycle {log_file} {
    # Чтение лог-файла
    set fp [open $log_file r]
    set content [read $fp]
    close $fp

    # Поиск всех маркеров >>start>> с PID
    set start_matches [regexp -all -inline {>>start>>\[PID:\s+(\d+)\]} $content]

    # Поиск всех маркеров >>stop>> с PID
    set stop_matches [regexp -all -inline {>>stop>>\[PID:\s+(\d+)\]} $content]

    # Проверка количества маркеров
    if {[llength $start_matches] != [llength $stop_matches]} {
        puts "ERROR: Start markers: [llength $start_matches], Stop markers: [llength $stop_matches]"
        return 0
    }

    # Проверка соответствия PID
    for {set i 0} {$i < [llength $start_matches]} {incr i 2} {
        set start_pid [lindex $start_matches [expr {$i + 1}]]
        set stop_pid [lindex $stop_matches [expr {$i + 1}]]

        if {$start_pid != $stop_pid} {
            puts "ERROR: PID mismatch - Start: $start_pid, Stop: $stop_pid"
            return 0
        }

        puts "INFO: Validated lifecycle for PID $start_pid"
    }

    puts "INFO: Lifecycle validation successful"
    return 1
}
```

### 8.3 Пример главного тест-раннера

**Файл:** `tests/expect/run-all.exp`

```tcl
#!/usr/bin/env expect
# @description: Главный тест-раннер для запуска всех тестов

# Список тестов
set tests {
    "menu-exit.exp"
    "menu-check.exp"
    "ssh-modify.exp"
    "ssh-rollback.exp"
    "ufw-modify.exp"
    "ufw-rollback.exp"
}

# Счетчики
set total 0
set passed 0
set failed 0

# Запуск каждого теста
foreach test $tests {
    incr total
    puts "\n========================================"
    puts "Running test: $test"
    puts "========================================"

    set test_path "tests/expect/scenarios/$test"

    # Запуск теста
    set result [catch {exec expect $test_path} output]

    # Проверка результата
    if {$result == 0} {
        incr passed
        puts "PASS: $test"
    } else {
        incr failed
        puts "FAIL: $test"
        puts "Output: $output"
    }
}

# Вывод итогов
puts "\n========================================"
puts "Test Summary"
puts "========================================"
puts "Total: $total"
puts "Passed: $passed"
puts "Failed: $failed"

# Возврат кода завершения
if {$failed > 0} {
    exit 1
} else {
    exit 0
}
```

---

## 9. Критерии успеха

### 9.1 Функциональные критерии

1. **Все ветки меню протестированы:**
   - [ ] Ветка 0 (выход) протестирована
   - [ ] Ветка 00 (проверка системы) протестирована
   - [ ] Ветки 1-N (модули modify) протестированы

2. **Проверка log_start/log_stop:**
   - [ ] Для каждого сценария проверено наличие пары log_start/log_stop
   - [ ] PID в маркерах start и stop совпадают
   - [ ] Порядок маркеров правильный (start до stop)

3. **Автоматизация:**
   - [ ] Тесты могут запускаться одной командой (`expect tests/expect/run-all.exp`)
   - [ ] Тесты не требуют ручного вмешательства
   - [ ] Тесты возвращают корректные коды завершения

4. **Изоляция:**
   - [ ] Тесты не влияют друг на друга
   - [ ] Каждый тест создает свой собственный лог-файл
   - [ ] Тесты могут выполняться в любом порядке

### 9.2 Нефункциональные критерии

1. **Производительность:**
   - [ ] Каждый тест завершается менее чем за 60 секунд
   - [ ] Весь набор тестов завершается менее чем за 5 минут

2. **Надежность:**
   - [ ] Тесты стабильны и не flaky
   - [ ] Тесты корректно обрабатывают таймауты
   - [ ] Тесты корректно обрабатывают ошибки

3. **Поддерживаемость:**
   - [ ] Код тестов следует стандартам BSSS
   - [ ] Тесты хорошо документированы
   - [ ] Добавление новых тестов занимает менее 30 минут

---

## 10. Управление рисками

### 10.1 Возможные проблемы с Expect

| Риск | Вероятность | Влияние | Митигация |
|------|-------------|---------|-----------|
| Таймауты при ожидании вывода | Высокая | Средняя | Использовать разумные таймауты, добавить retry логику |
| Изменение текста меню ломает тесты | Средняя | Высокая | Использовать гибкие regex паттерны, обновлять тесты при изменениях |
| Проблемы с правами sudo | Средняя | Высокая | Предварительная настройка sudo без пароля для тестов |
| Конфликты между тестами | Низкая | Средняя | Изоляция тестов через отдельные лог-файлы |
| Проблемы с кодировкой | Низкая | Низкая | Использовать UTF-8, обрабатывать спецсимволы |

### 10.2 Решения проблем

**Таймауты:**
- Использовать динамические таймауты на основе сложности сценария
- Добавить логирование таймаутов для диагностики
- Использовать `expect_after` для обработки таймаутов

**Изменение текста меню:**
- Использовать минимально необходимые паттерны для ожидания
- Избегать жесткого совпадения всего текста
- Регулярно обновлять тесты при изменениях в BSSS

**Проблемы с правами sudo:**
- Настроить sudo без пароля для конкретных команд
- Использовать `sudo -S` для передачи пароля (если необходимо)
- Документировать требования к настройке sudo

**Конфликты между тестами:**
- Каждый тест должен возвращать систему в исходное состояние
- Использовать отдельные лог-файлы для каждого теста
- Очищать временные файлы после завершения тестов

**Проблемы с кодировкой:**
- Использовать UTF-8 для всех файлов
- Обрабатывать спецсимволы (например, `\r` для Enter)
- Использовать `exp_internal 1` для диагностики проблем с кодировкой

---

## 11. Следующие шаги

### 11.1 Немедленные действия

1. **Установить Expect:**
   ```bash
   sudo apt-get install expect
   ```

2. **Создать базовую структуру директорий:**
   ```bash
   mkdir -p tests/expect/lib
   mkdir -p tests/expect/scenarios
   mkdir -p tests/expect/logs
   ```

3. **Создать базовый файл хелперов:**
   - Создать `tests/expect/lib/expect-helpers.exp`
   - Реализовать базовые функции

4. **Реализовать первый тест:**
   - Создать `tests/expect/scenarios/menu-exit.exp`
   - Протестировать его

### 11.2 Планирование

1. **Фаза 1 (1-2 дня):** Базовая инфраструктура Expect
2. **Фаза 2 (1 день):** Тестирование простых сценариев
3. **Фаза 3 (1-2 дня):** Тестирование модулей check
4. **Фаза 4 (2-3 дня):** Тестирование модулей modify
5. **Фаза 5 (2-3 дня):** Тестирование rollback сценариев

**Общее время:** 7-11 дней

### 11.3 Ресурсы

- Виртуальная машина с Ubuntu
- Root/sudo доступ
- Expect 5.45 или выше
- Доступ к репозиторию BSSS

---

## Приложение A: Пример лог-файла

**Пример лог-файла для сценария выхода из меню:**

```
[ ] [bsss-main.sh]>>start>>[PID: 12345]
####################################################################################################
[ ] [01-os-check.sh]>>start>>[PID: 12346]
[v] [01-os-check.sh] Операционная система: Ubuntu 24.04 LTS
[ ] [01-os-check.sh]>>stop>>[PID: 12346]

[ ] [02-update-system.sh]>>start>>[PID: 12347]
[v] [02-update-system.sh] Система обновлена
[ ] [02-update-system.sh]>>stop>>[PID: 12347]

[ ] [03-sys-reload-check.sh]>>start>>[PID: 12348]
[v] [03-sys-reload-check.sh] Проверка sys-reload пройдена
[ ] [03-sys-reload-check.sh]>>stop>>[PID: 12348]
####################################################################################################

[?] [bsss-main.sh] Запустить настройку? [Y/n]: y

####################################################################################################
[ ]    1. 04-ssh-port-modify.sh
[ ]    2. 05-ufw-modify.sh
[ ]    0. Выход
[ ]    00. Проверка системы (check)
####################################################################################################

[?] [bsss-main.sh] Выберите модуль [0-2]: 0

[ ] [bsss-main.sh] Выход из меню настройки

[ ] [bsss-main.sh]>>stop>>[PID: 12345]
```

---

## Приложение B: Справочник по Expect

### B.1 Основные команды Expect

| Команда | Описание |
|---------|----------|
| `spawn command` | Запуск команды для взаимодействия |
| `expect pattern` | Ожидание появления паттерна в выводе |
| `send string` | Отправка строки в процесс |
| `interact` | Передача управления пользователю |
| `set timeout n` | Установка таймаута в секундах |
| `log_file file` | Запись вывода в файл |

### B.2 Регулярные выражения в Expect

| Паттерн | Описание |
|---------|----------|
| `exact` | Точное совпадение |
| `-re pattern` | Регулярное выражение |
| `glob` | Glob паттерн (как в shell) |
| `timeout` | Таймаут |
| `eof` | Конец файла |

### B.3 Переменные Expect

| Переменная | Описание |
|------------|----------|
| `$spawn_id` | ID запущенного процесса |
| `$expect_out(buffer)` | Весь вывод, совпавший с expect |
| `$expect_out(0,string)` | Первая группа совпадения |
| `$expect_out(1,string)` | Вторая группа совпадения |
| `$timeout` | Текущий таймаут |

---

**Версия документа:** 1.0  
**Дата создания:** 2026-01-21  
**Статус:** Draft
