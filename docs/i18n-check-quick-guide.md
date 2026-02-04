# I18n Translation Integrity Checker - Quick Guide

## Purpose

Automatically detect missing translation keys between languages during development.

## Quick Start

```bash
# Run the check
./check-i18n.sh

# Or run the full script directly
./lib/i18n/check_translations.sh
```

## Developer Workflow

### 1. Adding a New Message (Example)

```bash
# Add new key to Russian translation
echo 'I18N_MESSAGES["ssh.new.feature.msg"]="Описание новой функции"' >> lib/i18n/ru/ssh.sh

# Use in code
log_info "ssh.new.feature.msg"
```

### 2. Check for Missing Translations

```bash
./check-i18n.sh
```

**Output if key is missing in English:**
```
[!] ssh.sh: ключи в ru но НЕ в en:
    - ssh.new.feature.msg
[x] Всего различий: 1
```

### 3. Add Missing Translation

```bash
# Add to English translation
echo 'I18N_MESSAGES["ssh.new.feature.msg"]="Description of new feature"' >> lib/i18n/en/ssh.sh

# Verify
./check-i18n.sh
```

**Output if synchronized:**
```
[ ] Все переводы синхронизированы!
```

## Integration Options

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./check-i18n.sh || {
    echo "Translation issues detected! Fix them before committing."
    exit 1
}
```

### CI/CD Pipeline

Add to your CI configuration:

```yaml
test:
  script:
    - bash ./check-i18n.sh
```

### Makefile

```makefile
.PHONY: check-i18n
check-i18n:
    @./check-i18n.sh
```

## Exit Codes

- `0` - All translations synchronized
- `1` - Translation issues found

## Output Format

### Green Output `[ ]`
No issues found. All translations are synchronized.

### Yellow Output `[!]`
Missing translation keys detected. Shows:
- File name
- Language pair (e.g., "ключи в ru но НЕ в en")
- List of missing keys

### Red Output `[x]`
Summary of total issues found.

## Troubleshooting

### False Positives

If the checker reports issues but you think all keys are translated:

1. Check file syntax (no typos in key names)
2. Verify key is in correct file (common.sh vs ssh.sh)
3. Run the check twice to ensure consistency

### Duplicates

If a key appears twice in the output:

- This is normal for multi-directional comparison
- Each missing key is counted twice (once per direction)
- Focus on the key names, not the count

### Performance

The checker is fast (~0.1s for 2 languages, ~0.5s for 5+ languages).

For large projects, consider:
- Running only on changed files
- Caching results between runs
- Parallelizing language comparisons

## Best Practices

1. **Add keys immediately** - Add translation keys before using them in code
2. **Run check often** - Check after adding new messages
3. **Translate promptly** - Don't leave keys untranslated for long
4. **Use consistent naming** - Follow key naming convention strictly
5. **Test both languages** - Verify translations work in context

## Related Files

- `lib/i18n/check_translations.sh` - Main checker script
- `lib/i18n/README.md` - Complete i18n documentation
- `check-i18n.sh` - Quick wrapper script
- `lib/i18n/{lang}/*.sh` - Translation files
