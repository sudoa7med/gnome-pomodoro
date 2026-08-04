/*
 * Copyright (c) 2016 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */


namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnome/pomodoro/window.ui")]
    public class Window : Gtk.ApplicationWindow, Gtk.Buildable
    {
        private const int MIN_WIDTH = 500;
        private const int MIN_HEIGHT = 650;

        private const double FADED_IN = 1.0;
        private const double FADED_OUT = 0.2;

        private const double TIMER_LINE_WIDTH = 6.0;
        private const double TIMER_RADIUS = 165.0;

        private struct Name
        {
            public string name;
            public string display_name;
        }

        private const Name[] STATE_NAMES = {
            { "null", "" },
            { "pomodoro", N_("Pomodoro") },
            { "short-break", N_("Short Break") },
            { "long-break", N_("Long Break") }
        };

        public string mode {
            get {
                return this.stack.visible_child_name;
            }
            set {
                this.stack.visible_child_name = value;
            }
        }

        public string default_mode {
            get {
                return this.default_page;
            }
        }

        private unowned Pomodoro.Timer timer;

        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Stack timer_stack;
        [GtkChild]
        private unowned Gtk.ToggleButton state_togglebutton;
        [GtkChild]
        private unowned Gtk.Label minutes_label;
        [GtkChild]
        private unowned Gtk.Label seconds_label;
        [GtkChild]
        private unowned Gtk.Widget timer_box;
        [GtkChild]
        private unowned Gtk.Button pause_resume_button;
        [GtkChild]
        private unowned Gtk.Button skip_stop_button;
        [GtkChild]
        private unowned Gtk.Image pause_resume_image;
        [GtkChild]
        private unowned Gtk.Image skip_stop_image;
        private unowned Gtk.MenuButton activity_button;

        private GLib.Settings preferences_settings;

        private Pomodoro.Animation blink_animation;
        private string default_page;

        construct
        {
            var geometry = Gdk.Geometry () {
                min_width = MIN_WIDTH,
                max_width = -1,
                min_height = MIN_HEIGHT,
                max_height = -1
            };
            this.set_geometry_hints (this, geometry, Gdk.WindowHints.MIN_SIZE);

            // this.stack.add_titled (this.timer_stack, "timer", _("Timer"));
            this.stack.add_titled (new Pomodoro.StatsView (), "stats", _("Stats"));

            // TODO: this.default_page should be set from application.vala
            var application = Pomodoro.Application.get_default ();

            this.default_page = "timer";

            this.stack.visible_child_name = this.default_page;

            var debug_stats = GLib.Environment.get_variable ("POMODORO_STATS");
            if (debug_stats != null)
            {
                this.stack.visible_child_name = "stats";
                GLib.debug ("POMODORO_STATS hook: stack child=%s", this.stack.visible_child_name);

                GLib.Idle.add (() => {
                    this.stack.visible_child_name = "stats";

                    var stats_view = this.stack.visible_child as Pomodoro.StatsView;
                    if (stats_view != null)
                    {
                        GLib.debug ("POMODORO_STATS idle: setting mode=%s", debug_stats);
                        stats_view.mode = debug_stats;
                    }
                    else
                    {
                        GLib.debug ("POMODORO_STATS idle: stats_view is null (child=%s)",
                                    this.stack.visible_child_name);
                    }

                    return false;
                });
            }

            this.on_timer_state_notify ();
            this.on_timer_elapsed_notify ();
            this.on_timer_is_paused_notify ();

            this.update_buttons();
        }

        public void parser_finished (Gtk.Builder builder)
        {
            this.timer = Pomodoro.Timer.get_default ();
            this.insert_action_group ("timer", this.timer.get_action_group ());

            base.parser_finished (builder);

            var state_togglebutton = builder.get_object ("state_togglebutton");
            state_togglebutton.bind_property ("active",
                                              builder.get_object ("state_popover"),
                                              "visible",
                                              GLib.BindingFlags.BIDIRECTIONAL);

            this.preferences_settings = Pomodoro.get_settings ()
                    .get_child ("preferences");

            /* [GtkChild] fields are not bound yet during parser_finished,
             * so fetch the button from the builder instead. */
            this.activity_button = builder.get_object ("activity_button")
                    as Gtk.MenuButton;

            this.activity_button.label =
                    this.get_current_activity ();
            this.update_activity_menu ();

            this.preferences_settings.changed["current-activity"].connect (() => {
                this.activity_button.label = this.get_current_activity ();
            });
            this.preferences_settings.changed["activity-categories"].connect (() => {
                this.update_activity_menu ();
            });

            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);
        }

        private string get_current_activity ()
        {
            var current_activity = this.preferences_settings.get_string ("current-activity");
            var categories = this.preferences_settings.get_strv ("activity-categories");

            if (current_activity == "" || !(current_activity in categories))
            {
                current_activity = categories.length > 0
                        ? categories[0] : _("General");
            }

            return current_activity;
        }

        private void update_activity_menu ()
        {
            var menu = new Gtk.Menu ();
            var current_activity = this.get_current_activity ();
            var categories = this.preferences_settings.get_strv ("activity-categories");

            Gtk.RadioMenuItem? previous_radio = null;

            foreach (var category in categories)
            {
                Gtk.RadioMenuItem item;

                if (previous_radio != null) {
                    item = new Gtk.RadioMenuItem.with_label_from_widget (previous_radio, category);
                }
                else {
                    item = new Gtk.RadioMenuItem.with_label (null, category);
                }

                item.active = (category == current_activity);

                item.toggled.connect (() => {
                    if (item.active)
                    {
                        Pomodoro.Application.get_default ().commit_elapsed_and_pause ();
                        this.preferences_settings.set_string ("current-activity", category);
                        this.activity_button.label = category;
                    }
                });

                menu.append (item);
                previous_radio = item;
            }

            menu.append (new Gtk.SeparatorMenuItem ());

            var add_item = new Gtk.MenuItem.with_label (_("Add Activity…"));
            add_item.activate.connect (this.show_add_activity_dialog);
            menu.append (add_item);

            var manage_item = new Gtk.MenuItem.with_label (_("Manage Activities…"));
            manage_item.activate.connect (this.show_manage_activities_dialog);
            menu.append (manage_item);

            menu.show_all ();
            this.activity_button.popup = menu;
        }

        private void show_manage_activities_dialog ()
        {
            var window = this.get_toplevel () as Gtk.Window;

            var dialog = new Gtk.Dialog.with_buttons (
                    _("Manage Activities"),
                    window,
                    Gtk.DialogFlags.MODAL,
                    _("Close"), Gtk.ResponseType.CLOSE);
            dialog.set_default_response (Gtk.ResponseType.CLOSE);

            var content = dialog.get_content_area ();
            content.spacing = 12;
            content.margin_start = 12;
            content.margin_end = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;

            var list = new Gtk.ListBox ();
            list.selection_mode = Gtk.SelectionMode.NONE;
            list.set_size_request (280, -1);
            content.pack_start (list, true, true, 0);

            refresh_rows (list);

            dialog.response.connect ((response) => {
                dialog.destroy ();
            });

            dialog.show_all ();
        }

        private void refresh_rows (Gtk.ListBox list)
        {
            foreach (var child in list.get_children ()) {
                list.remove (child);
            }

            var categories = this.preferences_settings.get_strv ("activity-categories");

            foreach (var category in categories)
            {
                var row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
                row.margin_start = 8;
                row.margin_end = 8;
                row.margin_top = 4;
                row.margin_bottom = 4;

                var label = new Gtk.Label (category);
                label.halign = Gtk.Align.START;
                label.hexpand = true;

                var delete_button = new Gtk.Button.with_label (_("Delete"));
                delete_button.get_style_context ().add_class ("destructive-action");
                delete_button.sensitive = categories.length > 1;

                delete_button.clicked.connect (() => {
                    var current = this.preferences_settings.get_strv ("activity-categories");

                    if (current.length <= 1) {
                        return;
                    }

                    var updated = new string[0];

                    foreach (var current_category in current) {
                        if (current_category != category) {
                            updated += current_category;
                        }
                    }

                    this.preferences_settings.set_strv ("activity-categories", updated);

                    if (this.preferences_settings.get_string ("current-activity") == category) {
                        this.preferences_settings.set_string ("current-activity", "");
                    }

                    refresh_rows (list);
                });

                row.pack_start (label, true, true, 0);
                row.pack_start (delete_button, false, false, 0);
                list.add (row);
            }
        }

        private void show_add_activity_dialog ()
        {
            var window = this.get_toplevel () as Gtk.Window;

            var dialog = new Gtk.Dialog.with_buttons (
                    _("Add Activity"),
                    window,
                    Gtk.DialogFlags.MODAL,
                    _("Cancel"), Gtk.ResponseType.CANCEL,
                    _("Add"), Gtk.ResponseType.OK);
            dialog.set_default_response (Gtk.ResponseType.OK);

            var entry = new Gtk.Entry ();
            entry.activates_default = true;

            var content = dialog.get_content_area ();
            content.spacing = 12;
            content.margin_start = 12;
            content.margin_end = 12;
            content.margin_top = 12;
            content.margin_bottom = 12;
            content.pack_start (entry, false, false, 0);

            dialog.show_all ();
            entry.grab_focus ();

            dialog.response.connect ((response) => {
                if (response == Gtk.ResponseType.OK)
                {
                    var name = entry.text.strip ();
                    if (name != "")
                    {
                        var categories = this.preferences_settings.get_strv ("activity-categories");

                        if (!(name in categories))
                        {
                            categories += name;
                            this.preferences_settings.set_strv ("activity-categories", categories);
                        }

                        this.preferences_settings.set_string ("current-activity", name);
                    }
                }

                dialog.destroy ();
            });
        }

        private void update_buttons ()
        {
            if (this.timer.is_paused) {
                this.pause_resume_image.icon_name = "media-playback-start-symbolic";
                this.pause_resume_button.action_name = "timer.resume";
                this.skip_stop_image.icon_name = "media-playback-stop-symbolic";
                this.skip_stop_button.action_name = "timer.stop";
            }
            else {
                this.pause_resume_image.icon_name = "media-playback-pause-symbolic";
                this.pause_resume_button.action_name = "timer.pause";
                this.skip_stop_image.icon_name = "media-skip-forward-symbolic";
                this.skip_stop_button.action_name = "timer.skip";
            }

            switch (this.timer.state.name)
            {
                case "pomodoro":
                    if (this.timer.is_paused) {
                        this.pause_resume_button.tooltip_text = _("Resume Pomodoro");
                        this.skip_stop_button.tooltip_text = _("Stop");
                    }
                    else {
                        this.pause_resume_button.tooltip_text = _("Pause Pomodoro");
                        this.skip_stop_button.tooltip_text = _("Take a break");
                    }

                    break;

                case "short-break":
                case "long-break":
                    if (this.timer.is_paused) {
                        this.pause_resume_button.tooltip_text = _("Resume break");
                        this.skip_stop_button.tooltip_text = _("Stop");
                    }
                    else {
                        this.pause_resume_button.tooltip_text = _("Pause break");
                        this.skip_stop_button.tooltip_text = _("Start Pomodoro");
                    }
                    break;

                default:
                    break;
            }
        }

        private void on_blink_animation_complete ()
        {
            if (this.timer.is_paused) {
                this.blink_animation.start_with_value (1.0);
            }
        }

        private void on_timer_state_notify ()
        {
            this.timer_stack.visible_child_name = 
                    (this.timer.state is Pomodoro.DisabledState) ? "disabled" : "enabled";

            this.update_buttons();

            foreach (var mapping in STATE_NAMES)
            {
                if (mapping.name == this.timer.state.name && mapping.display_name != "") {
                    this.state_togglebutton.label = mapping.display_name;
                    break;
                }
            }
        }

        private void on_timer_elapsed_notify ()
        {
            if (!(this.timer.state is Pomodoro.DisabledState))
            {
                var remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
                var minutes   = remaining / 60;
                var seconds   = remaining % 60;

                this.minutes_label.label = "%02u".printf (minutes);
                this.seconds_label.label = "%02u".printf (seconds);

                this.timer_box.queue_draw ();
            }
        }

        private void on_timer_is_paused_notify ()
        {
            if (this.blink_animation != null) {
                this.blink_animation.stop ();
                this.blink_animation = null;
            }

            this.update_buttons();

            if (this.timer.is_paused) {
                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.BLINK,
                                                               2500,
                                                               25);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   FADED_OUT);
                this.blink_animation.complete.connect (this.on_blink_animation_complete);
                this.blink_animation.start_with_value (1.0);
            }
            else {
                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.EASE_OUT,
                                                               200,
                                                               50);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   1.0);
                this.blink_animation.start ();
            }
        }

        [GtkCallback]
        private bool on_timer_box_draw (Gtk.Widget    widget,
                                        Cairo.Context context)
        {
            if (!(this.timer.state is Pomodoro.DisabledState))
            {
                var style_context = widget.get_style_context ();
                var color         = style_context.get_color (widget.get_state_flags ());

                var width  = widget.get_allocated_width ();
                var height = widget.get_allocated_height ();
                var x      = 0.5 * width;
                var y      = 0.5 * height;
                var progress = this.timer.state_duration > 0.0
                        ? this.timer.elapsed / this.timer.state_duration : 0.0;

                var angle1 = - 0.5 * Math.PI - 2.0 * Math.PI * progress.clamp (0.000001, 1.0);
                var angle2 = - 0.5 * Math.PI;

                context.set_line_width (TIMER_LINE_WIDTH);

                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * 0.1);
                context.arc (x, y, TIMER_RADIUS, 0.0, 2 * Math.PI);
                context.stroke ();

                context.set_line_cap (Cairo.LineCap.ROUND);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * FADED_IN - (color.alpha * 0.1) * (1.0 - FADED_IN));

                context.arc_negative (x, y, TIMER_RADIUS, angle1, angle2);
                context.stroke ();
            }

            return false;
        }

        [GtkCallback]
        private bool on_button_press (Gtk.Widget      widget,
                                      Gdk.EventButton event)
        {
            if (event.button == 1) {
                this.begin_move_drag ((int) event.button, (int) event.x_root, (int) event.y_root, event.time);

                return true;
            }

            return false;
        }
    }
}
