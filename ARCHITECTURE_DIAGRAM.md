# Диаграмма архитектуры BSSS

## Общая архитектура

```mermaid
graph TB
    A[Пользователь запускает one-line команду] --> B[launcher.sh]
    B --> C[Проверка кеша]
    C --> D{Модули в кеше?}
    D -->|Нет| E[Загрузка модулей из репозитория]
    D -->|Да| F[Использование модулей из кеша]
    E --> G[Сохранение в кеш]
    G --> F
    F --> H[bsss-main.sh]
    H --> I[Парсинг аргументов]
    I --> J[Проверка прав]
    J --> K[Последовательное выполнение шагов]
    
    K --> L[system-check]
    K --> M[system-update]
    K --> N[ssh-port]
    K --> O[ipv6-disable]
    K --> P[ssh-auth]
    K --> Q[ufw-setup]
    
    L --> R[Глобальные переменные состояния]
    M --> R
    N --> R
    O --> R
    P --> R
    Q --> R
```

## Архитектура модуля

```mermaid
graph TD
    A[Вызов модуля] --> B{Режим выполнения}
    
    B -->|check| C[check_current_state]
    C --> D[Возврат состояния]
    
    B -->|default| E[restore_default_settings]
    E --> F[Удаление bsss файлов]
    F --> G[Применение настроек]
    
    B -->|normal| H[module_init]
    H --> I[check_current_state]
    I --> J{Состояние изменять?}
    J -->|Нет| K[Завершение]
    J -->|Да| L[generate_filename]
    L --> M[create_config_file]
    M --> N[apply_settings]
    N --> O[Обновление глобальных переменных]
```

## Взаимодействие между модулями

```mermaid
graph LR
    A[ssh-port] -->|Устанавливает SSH_PORT| B[Глобальная переменная SSH_PORT]
    B -->|Читает SSH_PORT| C[ufw-setup]
    
    D[helpers/config.sh] --> A
    D --> C
    
    E[helpers/input.sh] --> A
    
    F[helpers/common.sh] --> A
    F --> C
```

## Поток данных при поиске конфигурации

```mermaid
graph TD
    A[find_last_active_parameter] --> B[Проверка основного конфига]
    B --> C[Найден параметр?]
    C -->|Да| D[Сохранить значение и файл]
    C -->|Нет| E[Переход к .d директории]
    
    E --> F[Получение списка .conf файлов]
    F --> G[Сортировка по алфавиту]
    G --> H[Итерация по файлам]
    H --> I[Поиск параметра в файле]
    I --> J[Найден параметр?]
    J -->|Да| K[Обновить значение и файл]
    J -->|Нет| L[Следующий файл]
    K --> M[Есть еще файлы?]
    L --> M
    M -->|Да| H
    M -->|Нет| N[Возврат результата]
```

## Архитектура тестирования

```mermaid
graph TD
    A[test-runner.sh] --> B[Выбор сценария]
    B --> C[setup_test_environment]
    C --> D[Создание mock окружения]
    D --> E[run_scenario_tests]
    E --> F[Запуск модулей в тестовом режиме]
    F --> G[Проверка результатов]
    G --> H[cleanup_test_environment]
    H --> I[Удаление mock окружения]
    I --> J{Есть еще сценарии?}
    J -->|Да| B
    J -->|Нет| K[Завершение тестов]