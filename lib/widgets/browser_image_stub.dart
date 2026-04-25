// Stub-Implementierung fuer Mobile/Desktop.
// Wird ueber conditional import auf Nicht-Web-Plattformen geladen.
// Auf Mobile/Desktop nutzt BrowserSafeImage Image.asset und ruft diese
// Funktion nie auf - sie existiert nur, damit der conditional import
// kompiliert.

void registerImageFactory(String viewType, String url, String objectFit) {
  // No-op auf Mobile/Desktop
}
