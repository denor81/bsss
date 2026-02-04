# I18n (Internationalization) - Documentation

## Overview

BSSS uses a simple but effective i18n system based on Bash 4+ associative arrays. The system supports multiple languages with zero external dependencies.

## Architecture

### Directory Structure

 ```
lib/i18n/
├── check_translations.sh       # Translation integrity checker
├── test_unused_translations.sh # Unused translation keys checker
├── test_unknown_translations.sh # Unknown translation keys checker
├── core.sh                     # Core translation function _()
├── loader.sh                   # Language detection and loader
├── ru/                         # Russian translations
│   ├── common.sh
│   ├── ssh.sh
│   ├── system.sh
│   └── ufw.sh
└── en/                         # English translations
    ├── common.sh
    ├── ssh.sh
    ├── system.sh
    └── ufw.sh
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

## Usage

### In Code

Use the `_()` function or `i18n::get()` alias:

```bash
# Without arguments
log_info "ssh.ui.get_action_choice.available_actions"

# With arguments (printf-style)
log_info "ssh.socket.wait_for_ssh_up.info" "$port" "$timeout"

# Direct output
echo "$(_ 'ssh.menu.item_exit')"
```

### In Translation Files

Translation keys follow the convention: `module.submodule.action.message_type`

```bash
# lib/i18n/ru/ssh.sh
I18N_MESSAGES["ssh.ui.get_action_choice.available_actions"]="Доступные действия:"
I18N_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят"
```

## Translation Integrity Check

### Running the Check

To verify that all translation keys are synchronized across languages:

```bash
./lib/i18n/check_translations.sh
```

### Output

- **Green**: All translations synchronized
- **Yellow**: Missing keys detected with file names and keys listed
- **Red**: Summary of total issues found

### Example Output

```bash
$ ./lib/i18n/check_translations.sh

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
- **Yellow**: Deprecated `i18n::get()` calls (should use `_$()` instead)
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
[!] oneline-runner.sh:42: использование устаревшего стиля i18n::get вместо _$()
[ ] Всего ключей в переводах: 175
[ ] Используемых ключей в коде: 148
[ ] Неизвестных ключей в коде: 1
[ ] Устаревших вызовов i18n::get: 1

========================================
Summary
========================================
[x] Найдены проблемы: 2
[!] Добавьте недостающие переводы в соответствующие файлы
[!] Замените i18n::get на _() для использования актуального стиля
```

**When to run**:
- After adding new translation keys (verify they exist in all language files)
- When changing translation keys (check for typos)
- Before committing new features

### All Translation Checks

Run all translation tests together:

```bash
./lib/i18n/check_translations.sh
./lib/i18n/test_unused_translations.sh
./lib/i18n/test_unknown_translations.sh
```

Or create a wrapper script:
```bash
#!/bin/bash
set -euo pipefail
./lib/i18n/check_translations.sh
./lib/i18n/test_unused_translations.sh
./lib/i18n/test_unknown_translations.sh
```

### Test Interpretation Guide

| Test Result | Meaning | Action |
|------------|---------|--------|
| **Unused keys found** | Keys in translations but not in code | Remove keys or verify code paths |
| **Unknown keys found** | Keys in code but not in translations | Add translations or fix typos |
| **Deprecated i18n::get** | Old translation function style | Replace `i18n::get` with `_$()` |
| **No issues** | All translations are healthy | Proceed with development |

### Test Limitations

1. **Unused keys test**: Cannot detect conditional usage (keys used in `if` branches). Manual verification required for suspicious cases.
2. **Unknown keys test**: May report false positives for dynamically constructed keys (e.g., using variables).
3. **Code coverage**: Tests find keys in code but don't execute all code paths. Some keys might be unreachable.

Best practices:
- Review test results manually before acting
- Use code search to verify key usage patterns
- Test actual code paths when in doubt


## Key Naming Convention

Format: `module.submodule.action.message_type`

### Module Domains
- `common` - Shared/common messages
- `ssh` - SSH-related messages
- `ufw` - UFW/firewall messages
- `system` - System-level messages

### Message Types
- `.error_` - Error messages
- `.info_` - Informational messages
- `.success_` - Success messages
- `.warning_` - Warning messages
- `.hint_` - Input hints
- `.default_` - Default values

## Adding New Language

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
   # Edit lib/i18n/de/common.sh, ssh.sh, etc.
   ```

4. Update `loader.sh` to recognize new language:
   ```bash
   case "$detected_lang" in
       ru|en|de|...  # Add 'de' here
   ```

5. Test:
   ```bash
   echo "de" > .lang
   ./main.sh
   ```

## Common Pitfalls

1. **Missing keys**: Always run `check_translations.sh` after adding new messages
2. **Incorrect printf format**: Ensure `%s` placeholders match in all languages
3. **Inconsistent naming**: Follow the key naming convention strictly
4. **Hardcoded strings**: Use `_$()` for all user-facing messages

## Troubleshooting

### Key shows "[key] NOT TRANSLATED"

- Check that the key exists in translation files
- Verify the `.lang` file contains valid language code
- Run `check_translations.sh` to find inconsistencies

### Language not switching

- Check `.lang` file exists in project root
- Verify language code is supported in `loader.sh`
- Ensure no extra whitespace in `.lang` file

### check_translations.sh shows false positives

- Verify files are properly formatted (no syntax errors)
- Check that keys are unique within each file
- Ensure files use `I18N_MESSAGES["key"]="value"` format
