# SSH Socket Mode Check Module

## Overview

Модуль `04-ssh-socket-check.sh` предназначен для проверки и переключения режима работы SSH на Ubuntu системах.

## Problem

В современных Ubuntu (24.04, 26.04) SSH может работать в двух режимах:
1. **Socket activation** (ssh.socket) - новый метод по умолчанию
2. **Classic service** (ssh.service) - классический метод

При использовании socket-активации изменения в `/etc/ssh/sshd_config.d/*.conf` могут не применяться корректно, что приводит к проблемам с поднятием портов.

## Solution

Модуль автоматически проверяет текущий режим SSH при каждом запуске скрипта:
- Если `ssh.socket` активен, модуль предлагает переключиться на `ssh.service`
- При отказе от переключения выполнение скрипта прекращается с кодом 1 (strict mode)
- При согласии выполняется переключение и скрипт продолжает работу

## Module Files

- `modules/04-ssh-socket-check.sh` - основной модуль проверки (MODULE_TYPE: check)
- `modules/04-ssh-socket-helpers.sh` - хелперы для работы с SSH режимами
- `utils/test-ssh-modes.sh` - утилита для тестирования переключений

## Helper Functions

### `ssh::is_socket_mode()`
Проверяет, активен ли ssh.socket.

### `ssh::is_service_mode()`
Проверяет, активен ли ssh.service.

### `ssh::switch_to_service_mode()`
Переключает SSH с socket на service режим.

### `ssh::switch_to_socket_mode()`
Переключает SSH с service на socket режим (для тестирования).

### `ssh::validate_config()`
Проверяет конфигурацию sshd на валидность (`sshd -t`).

### `ssh::reset_failed_services()`
Сбрасывает счетчики ошибок сервисов systemd.

## Testing Utility

`utils/test-ssh-modes.sh` - утилита для тестирования переключений между режимами.

```bash
# Показать текущий режим
sudo bash utils/test-ssh-modes.sh status

# Переключить на socket режим (для тестирования)
sudo bash utils/test-ssh-modes.sh socket

# Переключить на service режим
sudo bash utils/test-ssh-modes.sh service

# Сбросить счетчики ошибок
sudo bash utils/test-ssh-modes.sh reset

# Проверить конфигурацию sshd
sudo bash utils/test-ssh-modes.sh validate
```

## Testing Workflow

### Тестирование модуля в режиме socket (эмуляция нового состояния Ubuntu)

1. Переключите на socket режим:
```bash
sudo bash utils/test-ssh-modes.sh socket
```

2. Проверьте статус:
```bash
sudo bash utils/test-ssh-modes.sh status
```

3. Запустите проверку модуля:
```bash
sudo bash modules/04-ssh-socket-check.sh
```

Модуль должен обнаружить socket-активацию и предложить переключиться.

### Тестирование модуля в режиме service (нормальное состояние)

1. Переключите на service режим:
```bash
sudo bash utils/test-ssh-modes.sh service
```

2. Проверьте статус:
```bash
sudo bash utils/test-ssh-modes.sh status
```

3. Запустите проверку модуля:
```bash
sudo bash modules/04-ssh-socket-check.sh
```

Модуль должен подтвердить, что SSH работает в классическом режиме.

## Integration

Модуль автоматически запускается при выполнении `run_modules_polling()` в `bsss-main.sh`, так как имеет тип `check`.

## Exit Codes

- `0` - режим корректен или успешно переключен
- `1` - отказ от переключения (strict mode, выполнение невозможно)

## Notes

- При отказе от переключения выполнение скрипта невозможно (strict mode)
- Модуль автоматически выполняется при каждом запуске скрипта
- Для корректной работы требуются права sudo для изменения состояния сервисов
