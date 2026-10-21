# Шрифты интерфейса

- [Russo One](https://fonts.google.com/specimen/Russo+One), Jovanny Lemonad: выразительные заголовки и названия карточек. Ресурс `display.tres`.
- [Exo 2](https://fonts.google.com/specimen/Exo+2), Natanael Gama: основной текст, HUD и кнопки. `regular.tres` использует вес 500, `semibold.tres` — 650.
- [DejaVu Sans 2.37](https://dejavu-fonts.github.io/): явный резерв для игровых символов ● ○ ✦ → Ⅱ ×. Подключён ко всем трём ролям, не требует установленных системных шрифтов.

Основные семейства содержат полный русский алфавит, включая Ё/ё, а также расширенную кириллицу. Прямоугольные формы сочетаются с фантастическим интерфейсом; большие массивы текста остаются более лёгкими, чем заголовки. Текст интерфейса увеличен на 2–3 пикселя, кнопки — с 17 до 19; увеличены подписи карты, органов и боевые числа.

TTF-файлы сохранены без изменений. Exo 2 и Russo One получены из официального репозитория Google Fonts на ревизии `47d54ca1ebb14fd864695f1d39dc734f39017c33`. DejaVu взят из официального релиза 2.37. Точные URL, архивные пути и SHA-256 указаны в `sources.json`; исходные метаданные Google Fonts — в `metadata/`.

Лицензии Exo 2 и Russo One: SIL Open Font License 1.1, тексты в `licenses/Exo2-OFL.txt` и `licenses/RussoOne-OFL.txt`. DejaVu: Bitstream Vera с изменениями DejaVu, оригинальные условия в `licenses/DejaVu-LICENSE.txt`. Пресеты Windows и Web включают лицензии и этот файл в экспорт. Старый Manrope сохранён для прежних материалов; его лицензия — `OFL.txt`.

Проверка кириллицы, символов и высоты строки: `godot --headless --path . --script res://tests/test_fonts.gd`. Графические снимки с текущими шрифтами: `godot --path . --audio-driver Dummy --script res://tools/capture_symbiote_ui.gd -- --fonts`.
