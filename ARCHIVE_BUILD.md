# Инструкция по созданию и публикации архива

## Создание архива

Для создания архива с проектом выполните следующие команды:

```bash
# Шаг 1: Создаём архив локально
VERSION="1.0.0"
tar --exclude='.git' --exclude='oneline-runner.sh' -czf "project-v${VERSION}.tar.gz" \
    local-runner.sh lib/ modules/ templates/

# Шаг 2: Создаём тег в Git
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Шаг 3: Публикуем на GitHub
gh release create v1.0.0 "project-v1.0.0.tar.gz" --title "Release v1.0.0"
```

## Запуск через oneline

Для запуска проекта используйте команду:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/oneline-runner.sh)
```

## Структура архива

Архив должен содержать следующие файлы и директории:
- `local-runner.sh` - основной скрипт запуска
- `lib/` - библиотеки (если есть)
- `modules/` - модули проекта
- `templates/` - шаблоны (если есть)

## Исключения из архива

Из архива исключаются:
- `.git/` - директория git
- `oneline-runner.sh` - скрипт загрузки (он загружается отдельно)