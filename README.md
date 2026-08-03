# GNOME Pomodoro

## Download

```bash
git clone https://github.com/sudoa7med/gnome-pomodoro.git
cd gnome-pomodoro
```

## Dependencies (Ubuntu/Debian)

```bash
sudo apt install meson ninja-build valac \
  libglib2.0-dev libgtk-3-dev libgdk-pixbuf-2.0-dev libcairo2-dev \
  libgirepository1.0-dev gobject-introspection libpeas-2-dev \
  libgom-1.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libcanberra-dev libjson-glib-dev libsqlite3-dev
```

## Build and install

```bash
meson setup build
ninja -C build
sudo ninja -C build install
```

This installs the app to `/usr` (binary `/usr/bin/gnome-pomodoro`, library
`/usr/lib/x86_64-linux-gnu/libgnome-pomodoro.so`), compiles the GSettings
schemas, and registers the desktop entry.

## Run

Launch the indicator:

```bash
/usr/bin/gnome-pomodoro --no-default-window
```

Open the stats window directly on a specific page (debug hook):

```bash
POMODORO_STATS=day   gnome-pomodoro
POMODORO_STATS=week  gnome-pomodoro
POMODORO_STATS=month gnome-pomodoro
```

Or open stats from the running app via D-Bus:

```bash
gdbus call --session --dest org.gnome.Pomodoro \
  --object-path /org/gnome/Pomodoro \
  --method org.gnome.Pomodoro.ShowMainWindow "stats" 0
```

## Update (one command)

Pull, build, install and restart in a single step:

```bash
./update-gnome-pomodoro.sh
```

Or, if the alias is set up in `~/.zshrc`:

```bash
pomo-update
```

The script does: `git pull` → `meson setup --reconfigure` → `ninja build` →
`pkexec ninja install` (a password prompt will appear) → restart the
`gnome-pomodoro` daemon with the newly installed library.

## Reinstall after changes

```bash
ninja -C build            # rebuild
sudo ninja -C build install
pkill -x gnome-pomodoro   # restart so the new library is loaded
```

## License

This software is licensed under the [GPL 3](https://www.gnu.org/licenses/gpl-3.0.html).
