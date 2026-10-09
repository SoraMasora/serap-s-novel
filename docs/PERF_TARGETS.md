# Performance targets & measurements

## Бюджеты
| Метрика | Бюджет | Слабый таргет |
|---|---|---|
| Кадр (GPU-устройство, 1280×720) | ≤ 16.7 мс (60 FPS), p99 ≤ 33 мс | интегрированная графика, Chromium/Firefox |
| CPU `_process` на карте | ≤ 4 мс avg, ≤ 8 мс p99 | 1 ядро ~2.9 ГГц |
| Загрузка веб-сборки до титула | ≤ 10 с на 50 Мбит/с | — |
| Размер веб-сборки | ≤ 50 МБ (сейчас 68 МБ — KI-002) | — |

## Замеры (commit d5d9034, 2026-10-09)
Хост: Intel Xeon @ 2.90 GHz, 2 vCPU, без GPU. Разрешение 1280×720. Пресет Web (nothreads, gl_compatibility).

| ID | Что | Сцена / состояние | Драйвер | n | avg | p95 | p99 | Вердикт |
|---|---|---|---|---|---|---|---|---|
| M-001 | CPU `_process` карты (3 прогона) | c1_gift_walk «Вечер · Вдвоём», герой ходит по кругу направлений | Godot headless, dummy | 600 | 3.99 / 2.07 / 2.66 мс | 8.47 / 3.51 / 3.70 | 8.47 / 3.51 / 3.70 | pass (avg ≤ 4) / p99 на границе |
| M-002 | Интервал rAF, титул | титул, частицы пыли | Chromium 153 + SwiftShader | 599 | 151.6 мс | 183.4 | 266.7 | info (софт-рендер; не таргет) |
| M-003 | Интервал rAF, диалог | магазин, реплика с печатью | Chromium 153 + SwiftShader | 599 | 130.8 мс | 150.1 | 216.7 | info |
| M-004 | Оригинал (веб), титул | для сравнения | Chromium 153 + SwiftShader | 299 | 77.2 мс | 133.3 | 166.7 | info |
| M-005 | Загрузка до титула | `boot_ms` web_smoke | localhost http.server | 4 | 12.9–13.1 с | — | — | fail (бюджет 10 с) |

Примечание: Performance.TIME_PROCESS обновляется дискретно (p95 = p99 = max в M-001). Кадровый бюджет на реальном GPU — UNVERIFIED (KI-003).
Команды: `godot --headless --audio-driver Dummy --path godot res://tests/perf/perf_pixel_map.tscn -- --frames=600`; `PERF=600 STEPS=… node tools/godot/web_smoke.cjs`.
