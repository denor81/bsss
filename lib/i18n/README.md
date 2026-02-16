# I18n (Internationalization) - Documentation

## Overview

BSSS uses a simple but effective i18n system based on Bash 4+ associative arrays. The system supports multiple languages with zero external dependencies.

## Architecture

### Directory Structure

```
lib/i18n/
 ├── .tests/                      # Test scripts directory
 │   ├── run.sh                   # Run all i18n tests
 │   ├── test_missing_translations.sh  # Unknown keys checker
 │   ├── test_translations.sh     # Translation integrity checker
 │   ├── test_unused_translations.sh   # Unused keys checker
 │   └── helpers/
 │       └── test_helpers.sh      # Common test helpers
 ├── critical/                    # Critical translations (loaded early)
 │   └── common.sh               # no_translate special key
 ├── loader.sh                    # Language detection and loader. Core translation function _()
 ├── language_installer.sh        # Language selection installer
 ├── ru/                          # Russian translations
 │   └── common.sh               # All Russian translations in single file
 └── en/                          # English translations
     └── common.sh               # All English translations in single file
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

Add the key to `lib/i18n/ru/common.sh` (Russian):

```bash
# lib/i18n/ru/common.sh
I18N_MESSAGES["common.menu_header"]="Доступные действия:"
I18N_MESSAGES["ssh.success_port_up"]="SSH порт %s успешно поднят"
```

### Step 2: Add English Translation

Add the same key with English translation to `lib/i18n/en/common.sh`:

```bash
# lib/i18n/en/common.sh
I18N_MESSAGES["common.menu_header"]="Available actions:"
I18N_MESSAGES["ssh.success_port_up"]="SSH port %s successfully raised"
```

### Step 3: Use in Code

Use the translation key in your code:

```bash
# Simple message without arguments
log_info "$(_ "common.menu_header")"

# Message with printf-style arguments
log_info "$(_ "ssh.success_port_up" "$port")"
```

## Translation Integrity Check

### Running the Check

To verify that all translation keys are synchronized across languages:

```bash
bash lib/i18n/.tests/run.sh
```

Or run individual tests:

```bash
# Check synchronization between languages
bash lib/i18n/.tests/test_translations.sh

# Check for missing/unknown keys
bash lib/i18n/.tests/test_missing_translations.sh

# Check for unused keys
bash lib/i18n/.tests/test_unused_translations.sh
```

### Output

- **Green**: All translations synchronized
- **Yellow**: Missing keys detected with file names and keys listed
- **Red**: Summary of total issues found

### Example Output

```bash
$ bash lib/i18n/.tests/test_translations.sh

Сверяет файлы переводов
All translations are synchronized
```

### Integration with Development Workflow

Recommended to run translation check:
1. **Before committing** - Ensure all new keys are translated
2. **In CI/CD** - Add `bash lib/i18n/.tests/run.sh` to automated tests
3. **After adding features** - Verify all new messages are translated

## Translation Tests

### Running All Tests

Run all i18n tests at once:
```bash
bash lib/i18n/.tests/run.sh
```

### Individual Tests

#### Test 1: Translation Synchronization
Checks that all translation keys exist in all language files:
```bash
bash lib/i18n/.tests/test_translations.sh
```

#### Test 2: Missing/Unknown Keys
Checks that all keys used in code exist in translation files:
```bash
bash lib/i18n/.tests/test_missing_translations.sh
```

#### Test 3: Unused Keys
Finds keys in translation files that are not used in code:
```bash
bash lib/i18n/.tests/test_unused_translations.sh
```

### Detailed Documentation

For comprehensive information about:
- How to interpret test results
- Common issues and their solutions
- Test architecture and implementation
- Best practices for working with translations

See **[`.tests/AGENTS.md`](.tests/AGENTS.md)** - Full guide for agents working with i18n tests.

## Adding New Language

Currently supported languages: **ru** (Russian, default) and **en** (English).

To add a new language (e.g., German):

1. Create language directory:
   ```bash
   mkdir -p lib/i18n/de
   ```

2. Copy translation file from `ru/`:
   ```bash
   cp lib/i18n/ru/common.sh lib/i18n/de/common.sh
   ```

3. Translate all values:
   ```bash
   # Edit lib/i18n/de/common.sh
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

- Check that key exists in translation files
- Verify that `.lang` file contains valid language code
- Run `bash lib/i18n/.tests/test_missing_translations.sh` to find inconsistencies

### Language not switching

- Check `.lang` file exists in project root
- Verify language code is supported in `loader.sh` (ru, en, or your custom language)
- Ensure no extra whitespace in `.lang` file

### Tests show false positives

- Verify files are properly formatted (no syntax errors)
- Check that keys are unique within each file
- Ensure files use `I18N_MESSAGES["key"]="value"` format
- Review [`.tests/AGENTS.md`](.tests/AGENTS.md) for detailed troubleshooting

## Reference: Complete Translation Files

### Available Translation Files

- `lib/i18n/ru/common.sh` - All Russian translations (common, SSH, UFW, system, permissions, user modules)
- `lib/i18n/en/common.sh` - All English translations (common, SSH, UFW, system, permissions, user modules)

### Translation File Organization

All translations for each language are consolidated in a single `common.sh` file. Keys are organized by domain prefix:

- `common.*` - Shared/common messages
- `ssh.*` - SSH-related messages
- `ufw.*` - UFW/firewall messages
- `system.*` - System-level messages
- `permissions.*` - SSH access permissions messages
- `user.*` - User creation messages
- `rollback.*` - Rollback messages
- `io.*` - Input/output messages
- `init.*` - Initialization messages
- `os.*` - OS check messages
- `module.*` - Module names

### Special Keys

- `no_translate` - Special key to pass through text without translation. Use for file paths and dynamically generated strings.
