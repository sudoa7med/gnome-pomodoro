import Adw from 'gi://Adw';
import Gio from 'gi://Gio';
import Gtk from 'gi://Gtk';

import {ExtensionPreferences, gettext as _} from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';


export default class PomodoroPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        const settings = this.getSettings();

        const page = new Adw.PreferencesPage({
            title: _('Pomodoro'),
            icon_name: 'gnome-pomodoro-symbolic',
        });
        window.add(page);

        const generalGroup = new Adw.PreferencesGroup({
            title: _('General'),
        });
        page.add(generalGroup);

        const indicatorTypes = ['icon', 'text', 'short-text'];
        const indicatorLabels = [_('Circle'), _('Timer'), _('Short Timer')];

        const indicatorRow = new Adw.ComboRow({
            title: _('Panel Indicator'),
            subtitle: _('Choose how the timer is displayed in the top bar'),
        });

        const model = new Gtk.StringList();
        for (const label of indicatorLabels)
            model.append(label);

        indicatorRow.set_model(model);

        const currentType = settings.get_string('indicator-type');
        const currentIndex = indicatorTypes.indexOf(currentType);
        indicatorRow.set_selected(currentIndex >= 0 ? currentIndex : 0);

        indicatorRow.connect('notify::selected', () => {
            const idx = indicatorRow.get_selected();
            if (idx < indicatorTypes.length)
                settings.set_string('indicator-type', indicatorTypes[idx]);
        });

        generalGroup.add(indicatorRow);

        const notifGroup = new Adw.PreferencesGroup({
            title: _('Notifications'),
        });
        page.add(notifGroup);

        const hideNotifRow = new Adw.SwitchRow({
            title: _('Hide System Notifications'),
            subtitle: _('Suppress other notifications during a pomodoro session'),
        });
        settings.bind('hide-system-notifications', hideNotifRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        notifGroup.add(hideNotifRow);

        const blurRow = new Adw.SwitchRow({
            title: _('Blur Effect'),
            subtitle: _('Use a blur effect for the screen overlay background'),
        });
        settings.bind('blur-effect', blurRow, 'active', Gio.SettingsBindFlags.DEFAULT);
        notifGroup.add(blurRow);
    }
}
