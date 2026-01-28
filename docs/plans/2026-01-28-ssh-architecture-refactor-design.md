# Дизайн рефакторинга SSH модулей для соответствия UFW архитектуре

**Дата**: 2026-01-28
**Ветка**: refactor/ssh-architecture
**Тип**: Architecture Refactoring

## Обзор

Рефакторинг SSH модулей (04-ssh-port-helpers.sh, 04-ssh-port-modify.sh) для соответствия паттерну UFW архитектуры, обеспечивающий строгую иерархию функций и единообразный нейминг.

## Цели

1. Четкая иерархия субдоменов: `orchestrator → toggle → status/log → action`
2. Единый стиль именования с UFW модулями
3. Разделение UI, логики и логирования
4. Улучшение читаемости и поддерживаемости

## Новая архитектура функций

### 1. ssh::menu:: (UI уровень)

`ssh::menu::display` - Отображение основного меню

`ssh::menu::display_exists_scenario` - Меню для сценария с существующими конфигами

`ssh::menu::get_user_choice` - Получение выбора пользователя

`ssh::menu::get_scenario_choice` - Выбор сценария установки

### 2. ssh::orchestrator:: (координация)

`ssh::orchestrator::dispatch_logic` - Основной диспетчер сценариев

`ssh::orchestrator::config_exists_handler` - Обработчик сценария с конфигами

`ssh::orchestrator::config_not_exists_handler` - Обработчик сценария без конфигов

`ssh::orchestrator::actions_after_port_change` - Действия после изменений

### 3. ssh::toggle:: (переключатели)

`ssh::toggle::install_port` - Установка порта с guard

`ssh::toggle::reset_port` - Сброс порта

`ssh::toggle::reinstall_port` - Переустановка порта

### 4. ssh::status:: (состояние)

`ssh::status::has_bsss_config` - Проверка наличия BSSS конфига

`ssh::status::is_port_active` - Проверка активности порта

### 5. ssh::log:: (логирование)

`ssh::log::bsss_configs` - Логирование BSSS конфигов (было ssh::config::log_bsss_with_ports)

`ssh::log::other_configs` - Логирование сторонних конфигов (было ssh::config::log_other_with_ports)

`ssh::log::active_port` - Логирование активного порта

## Основные flow'ы

### Flow 1: Установка нового порта (config_not_exists)

```
ssh::orchestrator::dispatch_logic
  └─> ssh::orchestrator::config_not_exists_handler
      ├─> ssh::menu::display_install_ui
      ├─> ssh::menu::get_user_choice
      ├─> ssh::ui::get_new_port
      ├─> [watchdog setup]
      ├─> ssh::toggle::install_port
      │   ├─> ssh::rule::reset_and_pass
      │   ├─> ufw::rule::reset_and_pass
      │   └─> ssh::port::install_new
      ├─> ssh::orchestrator::actions_after_port_change
      │   ├─> sys::service::restart
      │   ├─> ssh::log::active_port
      │   ├─> ssh::log::bsss_configs
      │   └─> ufw::log::rules
      └─> [confirm & stop watchdog]
```

### Flow 2: Сброс порта (config_exists → choice 1)

```
ssh::orchestrator::config_exists_handler
  ├─> ssh::log::bsss_configs
  ├─> ssh::menu::display_exists_scenario
  ├─> ssh::menu::get_scenario_choice
  └─> ssh::toggle::reset_port
      ├─> ssh::rule::reset_and_pass
      ├─> ufw::rule::reset_and_pass
      └─> ssh::orchestrator::actions_after_port_change
```

### Flow 3: Переустановка порта (config_exists → choice 2)

```
ssh::orchestrator::config_exists_handler
  ├─> [как Flow 2 до выбора]
  └─> ssh::toggle::reinstall_port (как Flow 1)
```

## План реализации

### modules/04-ssh-port-helpers.sh

1. Создать новый субдомен `ssh::menu::`
   - Вынести UI логику из orchestrator функций
   - Добавить функции: display_exists_scenario, get_scenario_choice, display_install_ui

2. Рефакторить `ssh::orchestrator::`
   - `config_exists` → `config_exists_handler`
   - `config_not_exists` → `config_not_exists_handler`
   - Удалить дублированный UI код
   - Использовать menu:: функции

3. Создать субдомен `ssh::toggle::`
   - `install_port_with_guard` → `install_port`
   - Добавить `reset_port`
   - Добавить `reinstall_port` (как alias к install_port)

4. Переименовать логирующие функции
   - `ssh::config::log_bsss_with_ports` → `ssh::log::bsss_configs`
   - `ssh::config::log_other_with_ports` → `ssh::log::other_configs`

### modules/04-ssh-port-modify.sh

1. Упростить `main()`
   - Удалить лишнюю проверку if-else для confirm_action
   - Использовать || return для обработки отказа

2. Добавить trap для EXIT
   - Добавить `trap ssh::exit::actions EXIT TERM INT`
   - Удалить `trap log_stop EXIT`

3. Создать `ssh::exit::actions`
   - Вызывать log_stop
   - Возвращать код выхода

## Обработка ошибок

- Сохранить существующую логику обработки кодов возврата
- Код 2 = намеренная отмена пользователем
- Код 3 = откат
- Другие > 0 = критическая ошибка

## Контракт функций

Все функции должны содержать аннотации:

```bash
# @type:        Orchestrator
# @description: Краткое описание
# @params:      параметры
# @stdin:       формат входных данных
# @stdout:      формат выходных данных
# @exit_code:   0 - успешно
#               2 - отменено пользователем
#               >0 - ошибка
```

## Тестирование

1. Проверка всех трех flow'ов
2. Проверка работы watchdog
3. Проверка rollback механизма
4. Проверка UI во всех сценариях
5. Проверка логирования

## Критерии успеха

1. Все функции имеют корректные префиксы (ssh::menu::, ssh::orchestrator::, ssh::toggle::, ssh::log::)
2. Flow'ы соответствуют диаграммам дизайна
3. Никакой дублированной логики
4. Все аннотации присутствуют и корректны
5. Паттерн полностью соответствует UFW

## Обратная совместимость

Изменения только во внутренней структуре кода. Внешний API (пользовательский интерфейс) остается без изменений.
