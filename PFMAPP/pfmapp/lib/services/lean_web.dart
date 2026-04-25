// Only used on Flutter Web
import 'dart:js' as js;

void openLean(Map<String, dynamic> config) {
  if (!js.context.hasProperty('Lean')) {
    throw Exception("Lean SDK not loaded. Add it to web/index.html");
  }

  js.context['Lean'].callMethod('connect', [js.JsObject.jsify(config)]);
}
