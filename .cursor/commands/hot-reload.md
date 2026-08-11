# Hot reload / проверка на устройстве

1. Через MCP `user-dart`: `list_devices`, при необходимости `launch_app` / `hot_reload` / `get_runtime_errors`
2. Если MCP недоступен: подскажи `flutter run` / `r` в терминале
3. После правок UI — hot reload; после смены providers/main/native — hot restart
4. Сообщи по-русски: что перезагружено и есть ли runtime errors
