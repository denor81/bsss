# Node.js NPM CLI Package - Best Practices для разработки

## 1. Структура проекта и организация кода

### 1.1 Структурировать решение по компонентам
- Разделите код на компоненты, каждый в своей папке или кодовой базе
- Каждый компонент должен быть небольшим и простым
- Используйте паттерн монорепо или мультирепо
- Структура примера:
  ```
  my-app
  ├─ src/
  │ ├─ components/
  │ │ ├─ component-a/
  │ │ ├─ component-b/
  │ ├─ shared/
  │ ├─ index.js
  ├─ bin/
  │ ├─ cli.js (с shebang: #!/usr/bin/env node)
  ├─ package.json
  ├─ .npmignore или files в package.json
  ```

### 1.2 Слоистая архитектура компонентов
- Entry-points: контроллеры, CLI handlers
- Domain: бизнес-логика, DTOs, сервисы
- Data-access: обращения к БД без ORM

### 1.3 Переиспользуемые модули как npm пакеты
- Создавайте приватные npm пакеты для общих утилит
- Каждый модуль должен иметь свой package.json
- Используйте явный entry point (main/exports в package.json)

### 1.4 Явная точка входа для модуля/папки
- Установите файл index.js или используйте поле package.json.main
- Для ESM используйте поле package.json.exports
- Это служит 'интерфейсом' и облегчает будущие изменения

### 1.5 Конфигурация с учетом окружения
- Читайте конфиг из файла И переменных окружения
- Храните секреты вне committed кода
- Используйте иерархическую конфигурацию
- Рекомендуемые пакеты: convict, env-var, zod
- Используйте .env файлы для локальной разработки

## 2. Структура NPM пакета для CLI

### 2.1 Конфигурация package.json
```json
{
  "name": "@scope/my-cli-app",
  "version": "1.0.0",
  "description": "Описание приложения",
  "type": "module",
  "main": "./lib/index.js",
  "types": "./lib/index.d.ts",
  "bin": {
    "my-app": "./bin/cli.js",
    "my-app-cmd": "./bin/alternative-cmd.js"
  },
  "exports": {
    ".": {
      "import": "./lib/index.js",
      "types": "./lib/index.d.ts"
    }
  },
  "files": [
    "lib/**/*",
    "bin/**/*"
  ],
  "scripts": {
    "build": "tsc -p ./tsconfig.json",
    "test": "node --experimental-strip-types --test",
    "lint": "eslint src/**/*.ts",
    "prepack": "npm run build"
  },
  "engines": {
    "node": ">=18.0.0"
  },
  "publishConfig": {
    "access": "public"
  },
  "keywords": ["cli", "tool"],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/node": "^20.0.0"
  }
}
```

### 2.2 CLI Entry Point (bin/cli.js)
```javascript
#!/usr/bin/env node

import { createRequire } from "module";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const packageJson = require("../package.json");

// Ваша логика CLI приложения
async function main() {
  try {
    console.log(`v${packageJson.version}`);
    // основной код
  } catch (error) {
    console.error("Error:", error.message);
    process.exit(1);
  }
}

main();
```

### 2.3 TypeScript конфигурация (tsconfig.json)
```json
{
  "compilerOptions": {
    "lib": ["ES2024", "DOM"],
    "target": "ES2024",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "outDir": "./lib/",
    "declarationDir": "./lib/types",
    "strict": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true,
    "checkJs": true,
    "allowJs": true,
    "declaration": true,
    "declarationMap": true,
    "allowSyntheticDefaultImports": true
  },
  "files": ["./src/index.ts"]
}
```

## 3. Обработка ошибок

### 3.1 Используйте Async/Await вместо callbacks
- Избегайте "callback hell"
- Используйте async/await для читаемого и поддерживаемого кода
- Предпочитайте Promises native async/await

### 3.2 Встроенный объект Error
- Всегда используйте встроенный Error объект
- Создавайте собственные классы ошибок, наследуя от Error
- Различайте operational ошибки от programmer ошибок
- Operational: известные ошибки (invalid input), обрабатываются
- Programmer: неизвестные сбои кода, требуют перезагрузки

### 3.3 Централизованная обработка ошибок
- Создайте единый обработчик ошибок
- Все entry-points должны использовать этот обработчик
- Не разбрасывайте обработку по middleware

### 3.4 Отлавливайте unhandled promise rejections
```javascript
process.on('unhandledRejection', (reason, p) => {
  console.error('Unhandled Rejection at:', p, 'reason:', reason);
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('Caught exception:', error);
  process.exit(1);
});
```

### 3.5 Используйте зрелый логгер
- Избегайте console.log
- Используйте: Pino, Winston, Bunyan, Log4js
- Логгеры должны поддерживать уровни логирования
- Используйте структурированное логирование (JSON)

### 3.6 Всегда await перед return
```javascript
// Правильно
async function getData() {
  return await fetchData();
}

// Неправильно
async function getData() {
  return fetchData(); // потеря stack trace
}
```

## 4. Стиль кода

### 4.1 Используйте ESLint
- ESLint - стандарт для проверки ошибок и стиля кода
- Используйте Prettier для форматирования
- Используйте Node.js специфичные плагины: eslint-plugin-node, eslint-plugin-security

### 4.2 Соглашения об именовании
- Переменные, функции, константы: lowerCamelCase
- Классы: UpperCamelCase
- Глобальные константы: UPPER_SNAKE_CASE
- Используйте описательные имена, но короткие

### 4.3 Используйте const вместо let, избегайте var
- const предотвращает переназначение
- let используйте только когда переназначение необходимо
- var имеет function scope, не используйте в ES6+

### 4.4 Требуйте модули в начале файла
- Импортируйте все зависимости в начале
- Не импортируйте внутри функций
- Это показывает зависимости файла и избегает проблем инициализации

### 4.5 Используйте === вместо ==
- === не выполняет приведение типов
- Избегайте неожиданного поведения типов

### 4.6 Используйте async/await вместо callbacks
- async/await делает асинхронный код похожим на синхронный
- Поддерживается try-catch
- Читаемость и поддержка значительно лучше

### 4.7 Используйте arrow функции (=>)
- Более компактный синтаксис
- Сохраняет lexical контекст (this)
- Предпочитайте для callback'ов

### 4.8 Избегайте эффектов вне функций
- Не делайте DB/network вызовы в модульном корне
- Обрабатывайте такое в явно вызываемых функциях
- Это обеспечивает тестируемость и контроль инициализации

## 5. Тестирование и качество

### 5.1 Пишите тесты
- Минимум: API/component тесты
- Структурируйте по AAA паттерну: Arrange, Act, Assert
- Используйте описательные имена тестов (unit, scenario, expectation)

### 5.2 Конфигурация тестирования
```json
{
  "scripts": {
    "test": "node --experimental-strip-types --test",
    "test:watch": "node --watch --experimental-strip-types --test"
  }
}
```

### 5.3 Проверка покрытия
- Используйте Istanbul/NYC для измерения покрытия
- Устанавливайте минимальный порог покрытия
- Это помогает выявить неправильные паттерны тестирования

### 5.4 Единая версия Node.js
- Используйте nvm, Volta или .nvmrc файл
- Все разработчики должны использовать одну версию
- Реплицируйте версию в CI и production

## 6. Управление зависимостями

### 6.1 Блокируйте версии зависимостей
- Используйте package-lock.json в git
- Используйте npm ci вместо npm install в production
- Это гарантирует одинаковые версии везде

### 6.2 Регулярно проверяйте уязвимости
- Используйте npm audit
- Используйте Snyk для автоматической проверки
- Интегрируйте в CI pipeline

### 6.3 Инспектируйте устаревшие пакеты
- Используйте npm outdated
- Регулярно обновляйте пакеты
- Удаляйте неиспользуемые зависимости

### 6.4 Защитите npm аккаунт
- Включите 2FA на npm
- Используйте automation tokens для CI/CD
- Никогда не коммитьте credentials

### 6.5 Избегайте публикации секретов
- Используйте .npmignore для исключения файлов
- Используйте поле files в package.json
- Проверьте перед публикацией с npm pack --dry-run

### 6.6 Используйте node: протокол для встроенных модулей
```javascript
import fs from 'node:fs';
import path from 'node:path';
import { createServer } from 'node:http';
```

## 7. Безопасность

### 7.1 Валидируйте входные данные
- Используйте dedicated валидационные библиотеки: Joi, Zod, AJV
- Проверяйте типы и формат
- Fail fast на невалидных данных

### 7.2 Используйте HTTPS
- Все сетевое взаимодействие должно быть зашифровано
- Используйте SSL/TLS сертификаты

### 7.3 Экранируйте вывод
- Экранируйте HTML, JS, CSS при отправке в браузер
- Избегайте XSS атак
- Используйте специализированные библиотеки

### 7.4 Защита паролей
- Используйте bcrypt или scrypt вместо встроенного crypto
- Никогда не сохраняйте пароли в plaintext

### 7.5 Предотвращайте SQL/NoSQL injection
- Используйте ORM/ODM библиотеки: Sequelize, Knex, Mongoose
- Используйте параметризованные запросы
- Никогда не используйте template strings для SQL

### 7.6 Установите правильные заголовки
- Используйте Helmet для HTTP заголовков безопасности
- Установите CSP, X-Frame-Options и др.

## 8. Publishing и Distribution

### 8.1 Подготовка к публикации
- Убедитесь что package.json имеет правильное имя и версию
- Используйте semantic versioning (MAJOR.MINOR.PATCH)
- Создайте README.md с примерами использования

### 8.2 Процесс публикации
```bash
# Проверьте что будет опубликовано
npm pack --dry-run

# Проверьте процесс публикации без реальной публикации
npm publish --dry-run

# Опубликуйте пакет
npm publish --access=public  # для scoped пакетов
```

### 8.3 Автоматизируйте версионирование и публикацию
- Используйте semantic-release с conventional commits
- Автоматизируйте через GitHub Actions или подобное
- Это обеспечивает консистентное версионирование

### 8.4 Conventional Commits формат
```
feat: новая фишка
fix: исправление бага
docs: только документация
style: форматирование, missing semicolons, etc.
refactor: рефакторинг кода
perf: улучшение производительности
test: добавление тестов
chore: обновление зависимостей, build changes, etc.
breaking change: добавьте в footer если есть breaking changes
```

## 9. CI/CD Pipeline

### 9.1 Настройте автоматическое тестирование
- Запускайте тесты на каждый push/PR
- Используйте GitHub Actions, CircleCI, Jenkins и т.д.
- Проверяйте на нескольких версиях Node.js

### 9.2 Проверка качества кода
- Интегрируйте ESLint в CI
- Проверяйте покрытие тестами
- Используйте Snyk для проверки безопасности

### 9.3 Пример GitHub Actions workflow
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18.x, 20.x]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
      - run: npm ci
      - run: npm run lint
      - run: npm test
```

## 10. Производительность

### 10.1 Не блокируйте Event Loop
- Избегайте синхронных операций в production
- Не используйте fs.readFileSync, exec и т.д. в обработчиках
- Используйте worker threads для CPU-intensive операций

### 10.2 Кэширование
- Используйте Redis для in-memory кэширования
- Кэшируйте часто используемые данные
- Установите правильные HTTP кэш заголовки

### 10.3 Мониторинг
- Используйте APM инструменты (New Relic, Datadog)
- Отслеживайте память, CPU, response time
- Устанавливайте алерты на аномальное поведение

## 11. Docker Best Practices

### 11.1 Multi-stage builds
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["node", "bin/cli.js"]
```

### 11.2 .dockerignore файл
- Исключите node_modules, .git, .env и т.д.
- Предотвратите утечку секретов

### 11.3 Используйте меньшие base images
- Предпочитайте alpine вместо full Linux distro
- Это уменьшает size и attack surface

## 12. Локальная разработка

### 12.1 Тестирование npx локально
```bash
# Создайте тарбол пакета
npm pack

# В другой директории установите и протестируйте
npm install /path/to/package.tgz
# или
npx /path/to/package.tgz
```

### 12.2 Используйте npm link для разработки
```bash
# В папке пакета
npm link

# В папке приложения где тестируете
npm link @scope/my-cli-app
```

## 13. Документация

### 13.1 README.md должен содержать
- Описание
- Installation инструкции
- Usage примеры
- API документация
- Contributing guidelines
- License информация

### 13.2 Используйте JSDoc для кода
```javascript
/**
 * Описание функции
 * @param {string} name - Описание параметра
 * @returns {Promise<string>} Описание возвращаемого значения
 * @throws {Error} Описание ошибок которые может выбросить
 */
async function doSomething(name) {
  // реализация
}
```

## 14. Список инструментов и пакетов

### Базовые инструменты
- TypeScript: типобезопасность
- ESLint: проверка кода
- Prettier: форматирование
- Jest или Node.js test runner: тестирование

### Логирование и мониторинг
- Pino: быстрый JSON логгер
- Winston: полнофункциональный логгер
- Clinic.js: профилирование производительности

### Валидация
- Zod: TypeScript-first валидация
- Joi: мощная валидация
- AJV: JSON Schema валидация

### Утилиты CLI
- Commander.js: построение CLI
- Yargs: parsing аргументов
- Chalk: цветной вывод
- Ora: spinners для терминала

### Безопасность
- Helmet: HTTP заголовки
- bcrypt: хеширование паролей
- dotenv: управление .env файлами

### Управление версиями и публикацией
- semantic-release: автоматическое версионирование
- conventional-changelog: changelog генерация

### CI/CD
- GitHub Actions: встроенный CI/CD для GitHub
- Snyk: автоматическая проверка уязвимостей
