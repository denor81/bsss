# I18n (Internationalization) - Documentation

## Overview

BSSS uses a simple but effective i18n system based on Bash 4+ associative arrays. The system supports multiple languages with zero external dependencies.

## Architecture

### Directory Structure

```
lib/i18n/
├── test_translations.sh        # Translation integrity checker
├── test_unused_translations.sh  # Unused translation keys checker
├── test_unknown_translations.sh  # Unknown translation keys checker
├── loader.sh                    # Language detection and loader Core translation function _()
├── ru/                          # Russian translations
│   ├── common.sh
│   ├── ssh.sh
│   ├── system.sh
│   └── ufw.sh
└── en/                          # English translations
    ├── common.sh
    ├── ssh.sh
    ├── system.sh
    └── ufw.sh
```

### Core Translation Function

The `_()` function (defined in `lib/i18n/loader.sh`) is used to retrieve translations:

```bash
# @type:        Source
# @description: Переводчик сообщений по ключу
# @params:      message_key - Ключ сообщения в i18n системе
#               args - Аргументы для форматирования (опционально)
# @stdin:       нет
# @stdout:      Переведенное сообщение
# @exit_code:   0 - успех, 1 - ключ не найден
```

### Language Switching

The `.lang` file in the project root determines the current language:
- **Russian (default)**: No `.lang` file or `.lang` contains `ru`
- **English**: `.lang` contains `en`
- **Fallback**: Invalid language falls back to Russian

Example:
```bash
# Switch to English
echo "en" > .lang

# Switch to Russian (default)
rm -f .lang
# or
echo "ru" > .lang
```

## Usage Standards

### Translation Before Function Call

**IMPORTANT**: All functions (io::confirm_action, io::ask_value, log_info, log_error) expect already translated strings. Translate BEFORE calling the function, not inside it.

```bash
# Correct - translation done BEFORE function call
io::confirm_action "$(_ "key")"

# Correct - translation done BEFORE function call
io::ask_value "$(_ "key")" "$default" "$pattern" "$(_ "key" "arg1")" "n"

# Correct - log functions also expect translated strings
log_info "$(_ "key" "arg1" "arg2")"
log_error "$(_ "key")"
```

### Translations With Arguments

Translation keys can support printf-style formatting with arguments:

```bash
# Example in translation file:
# lib/i18n/ru/common.sh:
# I18N_MESSAGES["common.helpers.ufw.rule.delete_error"]="Ошибка удаления правила: %s"

# Usage in code:
log_error "$(_ "common.helpers.ufw.rule.delete_error" "$rule_args")"
```

### The `no_translate` Placeholder

There is a special key `no_translate` defined in common.sh that passes through text without translation:

```bash
# In translation file:
I18N_MESSAGES["no_translate"]="%s"

Use `no_translate` for:
- File paths
- Dynamically generated strings
- Output that should not be translated

### Key Naming Convention

Format: `module.submodule.action.message_type`

**Examples:**
- `common.error_root_privileges` - common errors
- `ssh.ui.get_action_choice.available_actions` - UI messages
- `ufw.status.enabled` - status messages

**Module Domains:**
- `common` - Shared/common messages
- `ssh` - SSH-related messages
- `ufw` - UFW/firewall messages
- `system` - System-level messages

**Message Types:**
- `.error_` - Error messages
- `.info_` - Informational messages
- `.success_` - Success messages
- `.warning_` - Warning messages
- `.hint_` - Input hints
- `.default_` - Default values

## Adding New Translations

### Step 1: Add Translation Key

Add the key to `lib/i18n/ru/domain.sh` (Russian):

```bash
# lib/i18n/ru/ssh.sh
I18N_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Доступные действия:"
I18N_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят"
```

### Step 2: Add English Translation

Add the same key with English translation to `lib/i18n/en/domain.sh`:

```bash
# lib/i18n/en/ssh.sh
I18N_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Available actions:"
I18N_MESSAGES["ssh.success_port_up"]="SSH port %s successfully raised"
```

### Step 3: Use in Code

Use the translation key in your code:

```bash
# Simple message without arguments
log_info "$(_ "ssh.ui.get_action_choice.available_actions")"

# Message with printf-style arguments
log_info "$(_ "ssh.success_port_up" "$port")"
```

## Translation Integrity Check

### Running the Check

To verify that all translation keys are synchronized across languages:

```bash
./lib/i18n/test_translations.sh
```

### Output

- **Green**: All translations synchronized
- **Yellow**: Missing keys detected with file names and keys listed
- **Red**: Summary of total issues found

### Example Output

```bash
$ ./lib/i18n/test_translations.sh

========================================
I18n Translation Integrity Check
========================================
[ ] Обнаруженные языки: en
ru

========================================
Сравнение: en <-> ru
========================================
[!] ssh.sh: ключи в ru но НЕ в en:
    - ssh.new.feature.msg

========================================
Summary
========================================
[x] Всего различий: 1
[!] Добавьте недостающие переводы в соответствующие файлы
```

### Integration with Development Workflow

Recommended to run the translation check:
1. **Before committing** - Ensure all new keys are translated
2. **In CI/CD** - Add to automated tests
3. **After adding features** - Verify all new messages are translated

## Translation Tests

### Unused Translation Keys Check

Finds translation keys that exist in translation files but are not used in the code:

```bash
./lib/i18n/test_unused_translations.sh
```

**Purpose**: Detects stale translations that should be removed or indicate code paths that were abandoned.

**Output**:
- **Yellow**: Lists unused keys by language
- **Summary**: Total unused keys count

**Example**:
```bash
$ ./lib/i18n/test_unused_translations.sh

========================================
I18n Unused Translations Check
========================================
[ ] Обнаруженные языки: en ru

========================================
Проверка языка: en
========================================
[!] Неиспользуемые ключи в переводах (en):
    - ssh.ui.get_action_choice.hint
    - ufw.error.disable_failed
[ ] Всего ключей в переводах: 175
[ ] Используемых ключей в коде: 145
[ ] Неиспользуемых ключей: 2

========================================
Summary
========================================
[!] Всего неиспользуемых ключей: 2
[!] Рекомендуется удалить неиспользуемые ключи из файлов переводов
```

**When to run**:
- Before removing translation keys (verify they're truly unused)
- After major refactoring
- During code cleanup

### Unknown Translation Keys Check

Finds translation keys used in code that don't exist in translation files:

```bash
./lib/i18n/test_unknown_translations.sh
```

**Purpose**: Detects typos in translation keys or missing translations for new features.

**Output**:
- **Red**: Unknown keys with file locations
- **Summary**: Total issues count

**Example**:
```bash
$ ./lib/i18n/test_unknown_translations.sh

========================================
I18n Unknown Translations Check
========================================
[ ] Обнаруженные языки: en ru

========================================
Проверка неизвестных ключей в коде
========================================
[x] main.sh:35: неизвестный ключ перевода 'common.error_root'
[ ] Всего ключей в переводах: 175
[ ] Используемых ключей в коде: 148
[ ] Неизвестных ключей в коде: 1

========================================
Summary
========================================
[x] Найдены проблемы: 1
[!] Добавьте недостающие переводы в соответствующие файлы
```

**When to run**:
- After adding new translation keys (verify they exist in all language files)
- When changing translation keys (check for typos)
- Before committing new features

### All Translation Checks

Run all translation tests together:

```bash
./lib/i18n/test_translations.sh
./lib/i18n/test_unused_translations.sh
./lib/i18n/test_unknown_translations.sh
```

Or create a wrapper script:
```bash
#!/bin/bash
set -euo pipefail
./lib/i18n/test_translations.sh
./lib/i18n/test_unused_translations.sh
./lib/i18n/test_unknown_translations.sh
```

### Test Interpretation Guide

| Test Result | Meaning | Action |
|------------|---------|--------|
| **Unused keys found** | Keys in translations but not in code | Remove keys or verify code paths |
| **Unknown keys found** | Keys in code but not in translations | Add translations or fix typos |
| **No issues** | All translations are healthy | Proceed with development |

### Test Limitations

1. **Unused keys test**: Cannot detect conditional usage (keys used in `if` branches).
2. **Unknown keys test**: May report false positives for dynamically constructed keys (e.g., using variables).
3. **Code coverage**: Tests find keys in code but don't execute all code paths. Some keys might be unreachable.

## Adding New Language

Currently supported languages: **ru** (Russian, default) and **en** (English).

To add a new language (e.g., German):

1. Create language directory:
   ```bash
   mkdir -p lib/i18n/de
   ```

2. Copy all translation files from `ru/`:
   ```bash
   cp lib/i18n/ru/*.sh lib/i18n/de/
   ```

3. Translate all values:
   ```bash
   # Edit lib/i18n/de/common.sh, ssh.sh, system.sh, ufw.sh
   ```

4. Update `loader.sh` to recognize new language:
   ```bash
   # Add 'de' to the case statement in loader.sh:
   case "$detected_lang" in
       ru|en|de)  # Add 'de' here
   ```

5. Test:
   ```bash
   echo "de" > .lang
   ./main.sh
   ```

## Common Pitfalls

1. **Missing keys**: Always run `test_translations.sh` after adding new messages
2. **Incorrect printf format**: Ensure `%s` placeholders match in all languages
3. **Inconsistent naming**: Follow the key naming convention strictly
4. **Hardcoded strings**: Use `_()` for all user-facing messages
5. **Translation inside functions**: Translate BEFORE calling io::confirm_action, io::ask_value, log_info, log_error

## Troubleshooting

### Key shows "[key] NOT TRANSLATED"

- Check that the key exists in translation files
- Verify the `.lang` file contains valid language code
- Run `test_translations.sh` to find inconsistencies

### Language not switching

- Check `.lang` file exists in project root
- Verify language code is supported in `loader.sh` (ru, en, or your custom language)
- Ensure no extra whitespace in `.lang` file

### test_translations.sh shows false positives

- Verify files are properly formatted (no syntax errors)
- Check that keys are unique within each file
- Ensure files use `I18N_MESSAGES["key"]="value"` format

## Reference: Complete Translation Files

### Available Translation Files

- `lib/i18n/ru/common.sh` - Common messages (Russian)
- `lib/i18n/ru/ssh.sh` - SSH module (Russian)
- `lib/i18n/ru/ufw.sh` - UFW module (Russian)
- `lib/i18n/ru/system.sh` - System messages (Russian)
- `lib/i18n/en/common.sh` - Common messages (English)
- `lib/i18n/en/ssh.sh` - SSH module (English)
- `lib/i18n/en/ufw.sh` - UFW module (English)
- `lib/i18n/en/system.sh` - System messages (English)

### Special Keys

- `no_translate` - Special key to pass through text without translation. Use for file paths and dynamically generated strings.
