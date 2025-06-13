# ML-Profiler

## Структура проекту

```
├── source/                          # Вихідний код embedded додатку
│   └── main.c                       # Головний файл з UART комунікацією
├── scripts/                         # Скрипти автоматизації та тестування
│   ├── gen_synthetic_models.py      # Генерація синтетичних ML моделей
│   ├── gen_calibration_data.py      # Створення калібраційних даних
│   ├── analyze_limits.py            # Аналіз граничних умов
│   ├── test_models.sh              # Головний скрипт тестування
│   ├── utils/                       # Допоміжні утиліти
│   │   ├── colors.sh               # Кольорове виведення в термінал
│   │   ├── dependencies.sh         # Створення директорій
│   │   ├── mtbml_config.sh         # Генерація .mtbml конфігурацій
│   │   └── metrics_extractor.sh    # Витягування метрик з логів
│   └── validation/                  # Модулі валідації
│       ├── model_tester.sh         # Логіка тестування моделей
│       ├── ml_configurator_validator.sh # ML Configurator валідація
│       └── summary_generator.sh    # Генерація звітів
├── pretrained_models/              # Директорія для .h5/.tflite моделей
├── test_data/                      # Калібраційні дані
│   └── test_data.csv              # CSV файл з тестовими даними
├── test_results/                   # Результати валідації
│   ├── ml_configurator_validation/ # Логи ML Configurator
│   └── validation_summary.md       # Підсумковий звіт
└── README.md                       # Документація проекту
```

#### `gen_synthetic_models.py` - Генерація ML моделей
```python
- Генерація моделей: small, medium, large, extra_large
- Збереження у форматах H5 та TFLite
- Квантизація: float32, int16x16, int16x8, int8x8
- Тренування на синтетичних даних MNIST-подібних
```

#### `gen_calibration_data.py` - Калібраційні дані
```python
# Створює тестові дані для валідації моделей
# Функціональність:
- Генерація випадкових features (784 для MNIST)
- CSV формат: target,feature1,feature2,...,feature784
- Налаштовувана кількість зразків та класів
```

#### `test_models.sh` - Головний скрипт тестування
```bash
# Автоматизоване тестування всіх моделей
# Функціональність:
- Пакетна обробка .h5/.tflite файлів
- Інтеграція з ml-configurator-cli
- Генерація .mtbml конфігурацій
- Підтримка різних типів квантизації
# Команди: --force, --enable-target, --quantization, --clean
```

#### `mtbml_config.sh` - Генерація конфігурацій
```bash
# Автоматична генерація .mtbml файлів для ML Configurator
# Функціональність:
- Налаштування quantization (float32, int8x8, int16x16, int16x8)
- Автовизначення COM портів (для Windows)
- Конфігурація калібраційних даних
```

#### `metrics_extractor.sh` - Витягування метрик
```bash
# Парсинг логів ML Configurator для отримання метрик
# Функції:
- extract_model_metrics() - cycles, memory, scratch
- extract_validation_metrics() - accuracy, errors
- extract_error_details() - деталі помилок
- extract_target_validation_metrics() - цільова валідація
```

#### `model_tester.sh` - Тестування моделей
```bash
- Пошук .h5/.tflite файлів
- Базове тестування (розмір файлів, шляхи)
- Виклик ML Configurator валідації
- Підрахунок протестованих моделей
```

#### `ml_configurator_validator.sh` - ML Configurator валідація
```bash
# Основна логіка валідації через ml-configurator-cli
- Конвертація моделей (--convert)
- Хостова валідація (--evaluate)
- Цільова валідація (--target-validate)
- Обробка помилок QEMU та TFLite
- Генерація детальних логів
```

#### `summary_generator.sh` - Генерація звітів
```bash
# Створює підсумкові звіти у Markdown форматі
- Результати валідації кожної моделі
- Статистику успіхів/помилок
- Деталі помилок конвертації
```
## Pipelines та автоматизація

1. **Генерація моделей**: `gen_synthetic_models.py` створює моделі різних розмірів
2. **Підготовка даних**: `gen_calibration_data.py` генерує тестові дані
3. **Автоматичне тестування**: `test_models.sh` запускає повний цикл валідації
4. **Конфігурація**: `mtbml_config.sh` створює .mtbml файли для кожної моделі
5. **Валідація**: `ml-configurator-cli` виконує конвертацію та валідацію
6. **Аналіз**: `metrics_extractor.sh` витягує метрики з логів
7. **Звітність**: `summary_generator.sh` створює підсумкові звіти
8. **UART керування**: `main.c` забезпечує інтерактивне керування через термінал

## 1. Використання зовнішніх .h5/.tflite моделей та калібраційних даних

**Реалізовано:**
- Скрипт `gen_synthetic_models.py` генерує моделі різних розмірів
- Скрипт `gen_calibration_data.py` створює синтетичні калібраційні дані
- Збереження у форматах H5 та TFLite

**Приклад використання:**
```bash
python gen_synthetic_models.py --models small medium large
python gen_calibration_data.py --samples 1000 --features 784
```

## 2. Граничні межі роботи "desktop-validation"

**Виявлені межі:**
- **БЕЗПЕЧНА ЗОНА**: <500KB пам'яті моделі (100% успіх)
- **ПОПЕРЕДЖУВАЛЬНА ЗОНА**: 500KB-1MB (конвертація OK, оцінка може зазнати невдачі)
- **ЗОНА ВІДМОВ**: >1MB (відмова оцінки QEMU)

**Конкретні результати:**
```
mnist_small:  212KB → SUCCESS
mnist_medium: 446KB → SUCCESS  
mnist_large:  980KB → QEMU FAILURE
```

**Межа за циклами:** ~2.3M циклів - максимум для конвертації

## 3. Причини неможливості конвертації та валідації

**Основні причини:**
1. **Обмеження пам'яті моделі** - QEMU не може обробити моделі >1MB
2. **Проблеми з QEMU** - зовнішня залежність, проблеми з шляхами Windows
3. **Якість квантизації** - синтетичні дані призводять до поганої квантизації INT8X8
4. **Несумісність TFLite** - попередньо конвертовані файли .tflite не працюють з QEMU
5. **Інтеграція інструментів** - TensorFlow → TFLite → QEMU створює точки відмов

## 4. CLI інструменти окрім GUI

**Знайдено CLI альтернативу:**
- `ml-configurator-cli` - повнофункціональна CLI версія GUI інструменту

**Основні команди:**
```bash
ml-configurator-cli --config model.mtbml --convert      # Конвертація
ml-configurator-cli --config model.mtbml --evaluate     # Хостова валідація
ml-configurator-cli --config model.mtbml --target-validate # Цільова валідація
```

**Автоматизація в `test_models.sh`:**
- Генерація .mtbml конфігурацій
- Обробка помилок
- Пакетна обробка моделей
- Використання `ml-configurator-cli` для конвертації та валідації
- Валідація моделей на хості та цільовому пристрої
- Зміна режимів квантизації
- Вивід результатів валідації у термінал та збереження у лог-файли 
- К

```bash

## 5. Керування через PuTTY/Terminal

**Налаштування підключення:**
- Швидкість: 115200 (USE_LOCAL_DATA) або 1000000 (USE_STREAM_DATA)
- Біти даних: 8, Стоп-біти: 1, Парність: Немає

**Користувацькі команди:**
```
help     - показати всі команди
start    - почати ML профілювання
clean    - очистити екран
exit     - вихід
```

**ML протокольні команди:**
```
TC_START             - ініціювати сесію
TC_MODEL_DATA_REQ    - запросити інформацію про модель
CT_FRAME_REQ         - обробити кадр
TC_DONE              - завершити сесію
```

## 6. Джерела CLI/COMx команд

### COM
1. **Git REPO** - містить перелік команд та діаграму.
2. **Include** - `mtb_ml_stream_impl.h` визначає константи протоколу
3. **Дослідження** - спостереження за передачею команд у `ml-configurator-gui`

### CLI 
1. **Документація ModusToolbox** - згадує `ml-configurator-cli`
2. **Команда help** - $ ml-configurator-cli --help

## 7. Зміна команд в коді

**Демонстрація зміни:**

### w:\MTB\Machine_Learning_Neural_Network_Profiler\source\main.c

Продемонструвати зміну команди "status" на "info" з додатковою інформацією.

 - Перенесення COM команд з `main.c` до `mtb_ml_stream_impl.h` для кращої організації та підтримки.
 - Додав команду "help" для відображення доступних команд.
 - Можливість очищення екрану за допомогою команди "clean".
 - Зміна команди "status" на "info" для відображення детальної інформації про пристрій.
 - Можливість відправлення команд через UART для взаємодії з пристроєм використовуючи PuTTY або інший термінал.

```c
// \main.c
                    } else if (strcmp(uart_buffer, "info") == 0) {  // Змінено з "status" на "info"
                        printf("=== Device Information ===\r\n");    // Змінено заголовок
                        printf("Operating Mode: %s\r\n", (REGRESSION_DATA_SOURCE == USE_STREAM_DATA) ? "STREAM" : "LOCAL");
                        if(model_object != NULL) {
                            printf("Model: %s\r\n", model_object->name);
                            printf("Model size: %d bytes\r\n", model_object->model_size);
                            printf("Input size: %d elements\r\n", model_object->input_size);
                            printf("Output size: %d elements\r\n", model_object->output_size);
                        }
                        printf("Device ID: CY8CKIT-062-BLE\r\n");     
                        printf("Profile config: %s\r\n",
                               (PROFILE_CONFIGURATION == MTB_ML_PROFILE_ENABLE_MODEL) ? "MODEL" : "OTHER");