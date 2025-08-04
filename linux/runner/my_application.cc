#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include <glib/gstdio.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Icon and application constants
static const gchar* const ICON_PRODUCTION_PATH = "data/flutter_assets/assets/icon/app_icon_1024.png";
static const gchar* const ICON_DEVELOPMENT_PATH = "assets/icon/app_icon_1024.png";
static const gchar* const ICON_ALTERNATIVE_PATH = "../assets/icon/app_icon_1024.png";
static const gchar* const ICON_RELATIVE_PATH = "../../../assets/icon/app_icon_1024.png";
static const gchar* const ICON_THEME_NAME = "com.matthiasnehlsen.lotti";
static const gchar* const APP_TITLE = "Lotti";
static const gchar* const WINDOW_NAME = "lotti";

// Helper function to get executable directory
static gchar* get_executable_dir() {
  gchar* exe_path = g_file_read_link("/proc/self/exe", NULL);
  if (!exe_path) {
    return NULL;
  }
  
  gchar* dir = g_path_get_dirname(exe_path);
  g_free(exe_path);
  return dir;
}

// Helper function to construct icon path relative to executable
static gchar* get_icon_path_relative_to_exe(const gchar* relative_path) {
  gchar* exe_dir = get_executable_dir();
  if (!exe_dir) {
    return NULL;
  }
  
  gchar* icon_path = g_build_filename(exe_dir, relative_path, NULL);
  g_free(exe_dir);
  return icon_path;
}

// Helper function to try loading an icon
static gboolean try_load_icon(GtkWindow* window, const gchar* icon_path, const gchar* debug_id) {
  g_autoptr(GError) error = NULL;
  if (gtk_window_set_icon_from_file(window, icon_path, &error)) {
#ifdef DEBUG
    g_debug("Successfully loaded icon from %s: %s", debug_id, icon_path);
#endif
    return TRUE;
  } else {
#ifdef DEBUG
    g_debug("Failed to load icon from %s: %s", debug_id, error ? error->message : "Unknown error");
#endif
    return FALSE;
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Set window properties for proper desktop integration
  // The application ID is already set in my_application_new() which provides WM_CLASS
  gtk_widget_set_name(GTK_WIDGET(window), WINDOW_NAME);

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, APP_TITLE);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, APP_TITLE);
  }

  // Try multiple icon paths to work in both development and production environments
  gboolean icon_loaded = FALSE;
  
  // Define icon paths once to avoid duplication
  const gchar* const icon_paths_to_try[] = {
    ICON_PRODUCTION_PATH,    // Production path
    ICON_DEVELOPMENT_PATH,   // Development path
    ICON_ALTERNATIVE_PATH,   // Alternative dev path
    ICON_RELATIVE_PATH,      // Relative path from build directory
    NULL
  };
  
  // Try executable-relative paths first
  for (gsize i = 0; icon_paths_to_try[i] != NULL && !icon_loaded; i++) {
    gchar* icon_path = get_icon_path_relative_to_exe(icon_paths_to_try[i]);
    if (icon_path != NULL) {
      icon_loaded = try_load_icon(window, icon_path, "executable-relative");
      g_free(icon_path);
    }
  }
  
  // Fallback to hardcoded paths if executable-relative paths failed
  if (!icon_loaded) {
    for (gsize i = 0; icon_paths_to_try[i] != NULL && !icon_loaded; i++) {
      icon_loaded = try_load_icon(window, icon_paths_to_try[i], "fallback");
    }
  }
  
  if (!icon_loaded) {
    g_warning("Could not load application icon from any file path, using theme fallback");
  }

  // Set the icon name for desktop integration fallback
  gtk_window_set_icon_name(window, ICON_THEME_NAME);

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
