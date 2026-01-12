# Манифест проектирования: Bash-инженерия 2026
1. Фундаментальная философия
 - Данный проект — это не «скрипт», это модульный фреймворк на базе Unix-утилит. Мы не пишем императивный код, мы проектируем потоки данных.
 - Bash как клей: Мы используем Bash для управления процессами и файловыми дескрипторами. Вся тяжелая работа (парсинг, трансформация) делегируется специализированным инструментам: awk, sed, grep, xargs.
 - Изоляция побочных эффектов: Каждая значимая модификация системы должна быть атомарной.
2. Золотой стандарт потоков (IO)
 - NUL-разделитель (\0): Единственный надежный способ передачи данных в пайплайнах. Пути к файлам, списки портов и любые массивы данных передаются через \0.
 - Догма: «NUL живет в трубе, но умирает в переменной».
 - Чистота FD 1 (stdout): Только чистые данные для следующего звена.
 - Диагностика FD 2 (stderr): Все логи, интерфейсы, подтверждения и интерактив — строго в stderr. (Используй систему логирования проекта - log_info, log_error и прочие в logging.sh, для подтверждения действия используй - io::confirm_action в user_confirmation.sh, для выбора значения io::ask_value там же.)
 - Запрет на eval: Никогда не использовать eval для выполнения строк, полученных из парсинга. Используй массивы, xargs или прямой вызов.
3. Архитектура ролей (Namespacing)
 - Функции обязаны иметь префиксы для обозначения своей зоны ответственности:
   - orchestrator:: — высокоуровневая логика и переключение сценариев.
   - ssh::, ufw::, grub:: и т.д. — специфичные провайдеры (библиотеки) для сервисов.
   - io:: — взаимодействие с пользователем и логирование.
   - sys:: — низкоуровневые системные проверки (порты, файлы, процессы).
4. Контракт функции (Аннотации)
 - Перед каждой функцией обязательна аннотация:
bash
```bash
# @type:        Source | Filter | Transformer | Orchestrator | Sink | UNDEFINED
# @description: Краткое описание физики действия
# @stdin:       Формат входящих данных (например, NUL-separated paths (path\0))
# @stdout:      Формат выходящих данных
# @exit_code:   0 - успех, >0 - ошибка
```
5. Инструментарий
 - Использование read -r -d ''.
 - Использование mapfile -d ''.
 - Использование sort -z, xargs -0.

6. Примеры
 - Оркестрация
 ```bash
# @type:        Orchestrator
# @description: Обработчик сценария отсутствия конфигурации SSH
#               Установка нового порта SSH и добавление правила в UFW
# @params:      нет
# @stdin:       нет
# @stdout:      нет
# @exit_code:   0 — упешно
#               $? — код ошибки дочернего процесса
orchestrator::bsss_config_not_exists() {
    ssh::ask_new_port | ssh::reset_and_pass | ufw::reset_and_pass | ssh::install_new_port
    orchestrator::actions_after_port_install
}
```
 - Фильтр
```bash
# @type:        Filter
# @description: Удаляет все правила UFW BSSS и передает порт дальше
# @params:      нет
# @stdin:       port\0 (опционально)
# @stdout:      port\0 (опционально)
# @exit_code:   0 - успешно
ufw::reset_and_pass() {
    local port=""

    # || true нужен что бы гасить код 1 при false кода [[ ! -t 0 ]]
    [[ ! -t 0 ]] && IFS= read -r -d '' port || true
    
    ufw::delete_all_bsss_rules

    # || true нужен что бы гасить код 1 при false кода [[ -n "$port" ]]
    [[ -n "$port" ]] && printf '%s\0' "$port" || true
}
```
 - Источник
```bash
# @type:        Source
# @description: Генерирует случайный свободный порт в диапазоне 10000-65535
# @params:      нет
# @stdin:       нет
# @stdout:      port
# @exit_code:   0 - порт успешно сгенерирован
#               $? - ошибка
ssh::generate_free_random_port() {
    while IFS= read -r port || break; do
        if ! ssh::is_port_busy "$port"; then
            printf '%s\n' "$port"
            return
        fi
    done < <(shuf -i 10000-65535)
}
```
   - Дополнительные приеры
     - [modules/04-ssh-port-helpers.sh](modules/04-ssh-port-helpers.sh)
     - [modules/04-ssh-port-modify.sh](modules/04-ssh-port-modify.sh)
     - [local-runner.sh](local-runner.sh)
