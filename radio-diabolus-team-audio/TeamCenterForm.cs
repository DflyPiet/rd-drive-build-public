// Radio Diabolus Team Audio Control, GPL-3.0-or-later.
// Uses the original SoundSwitch audio engine; copyright notices are retained upstream.
using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using SoundSwitch.Audio.Manager;
using SoundSwitch.Audio.Manager.Interop.Enum;
using SoundSwitch.Model;
using SoundSwitch.Properties;

namespace SoundSwitch.UI.Forms;

public sealed class TeamCenterForm : Form
{
    private static readonly Color Background = Color.FromArgb(18, 19, 24);
    private static readonly Color Surface = Color.FromArgb(31, 32, 40);
    private static readonly Color Accent = Color.FromArgb(220, 41, 62);
    private static readonly Color Foreground = Color.FromArgb(244, 244, 246);
    private static readonly Color Muted = Color.FromArgb(172, 175, 186);

    private readonly Label _output = DeviceLabel();
    private readonly Label _input = DeviceLabel();
    private readonly Label _status = new() { Text = "Bereit", ForeColor = Muted, Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleLeft };
    private readonly FlowLayoutPanel _profiles = new() { Dock = DockStyle.Fill, AutoScroll = true, WrapContents = true };
    private readonly System.Windows.Forms.Timer _timer = new() { Interval = 2500 };
    private Button _mute = null!;

    public TeamCenterForm()
    {
        Text = "Radio Diabolus | Team Audio Control";
        Icon = Resources.Switch_SoundWave;
        BackColor = Background;
        ForeColor = Foreground;
        Font = new Font("Segoe UI", 10);
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(860, 575);
        MinimumSize = new Size(760, 560);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4, Padding = new Padding(18) };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 95));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 185));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
        Controls.Add(layout);
        layout.Controls.Add(CreateHeader(), 0, 0);

        var devices = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, RowCount = 1 };
        devices.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        devices.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
        devices.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        devices.Controls.Add(DeviceCard("AUDIOAUSGANG", "Aktueller Wiedergabeausgang", _output, "Ausgang wechseln", EDataFlow.eRender), 0, 0);
        devices.Controls.Add(DeviceCard("MIKROFON / EINGANG", "Aktueller Aufnahmeeingang", _input, "Eingang wechseln", EDataFlow.eCapture), 1, 0);
        layout.Controls.Add(devices, 0, 1);

        var profilePanel = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 2, BackColor = Surface, Padding = new Padding(16), Margin = new Padding(0, 10, 0, 10) };
        profilePanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        profilePanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 40));
        profilePanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        profilePanel.Controls.Add(new Label { Text = "TEAMPROFILE", Dock = DockStyle.Fill, ForeColor = Foreground, Font = new Font("Segoe UI", 12, FontStyle.Bold) }, 0, 0);
        profilePanel.Controls.Add(_profiles, 0, 1);
        layout.Controls.Add(profilePanel, 0, 2);

        var footer = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 3, RowCount = 1 };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 195));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 150));
        footer.Controls.Add(_status, 0, 0);
        var settings = ActionButton("Audio-Einstellungen", false);
        settings.Click += (_, _) => AppModel.Instance.TrayIcon.ShowSettings();
        footer.Controls.Add(settings, 1, 0);
        var site = ActionButton("RADIO DIABOLUS", false);
        site.Click += (_, _) =>
        {
            try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://radio-diabolus.dk/site/") { UseShellExecute = true }); }
            catch (Exception ex) { ShowError(ex); }
        };
        footer.Controls.Add(site, 2, 0);
        layout.Controls.Add(footer, 0, 3);

        Shown += (_, _) => { RefreshDevices(); RefreshProfiles(); _timer.Start(); };
        Activated += (_, _) => { if (AppModel.Instance.ProfileManager != null) RefreshProfiles(); };
        FormClosed += (_, _) => { _timer.Stop(); _timer.Dispose(); };
        _timer.Tick += (_, _) => RefreshDevices();
    }

    private Control CreateHeader()
    {
        var header = new Panel { Dock = DockStyle.Fill };
        header.Controls.Add(new Label { Text = "RADIO DIABOLUS", Font = new Font("Segoe UI", 23, FontStyle.Bold), ForeColor = Foreground, AutoSize = true, Location = new Point(10, 4) });
        header.Controls.Add(new Label { Text = "TEAM AUDIO CONTROL  |  SOUNDS LIKE HELL", Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = Accent, AutoSize = true, Location = new Point(14, 54) });
        _mute = ActionButton("Mikrofon stumm", true);
        _mute.Size = new Size(190, 43);
        _mute.Location = new Point(600, 17);
        _mute.Anchor = AnchorStyles.Top | AnchorStyles.Right;
        _mute.Click += (_, _) =>
        {
            try
            {
                var result = AppModel.Instance.ToggleMicrophoneMute();
                if (result == null) throw new InvalidOperationException("Kein Mikrofon verfügbar.");
                _status.Text = result.Value.IsMuted ? "Mikrofon stummgeschaltet" : "Mikrofon eingeschaltet";
                RefreshDevices();
            }
            catch (Exception ex) { ShowError(ex); }
        };
        header.Controls.Add(_mute);
        header.Paint += (_, e) => { using var p = new Pen(Accent, 3); e.Graphics.DrawLine(p, 0, header.Height - 5, header.Width, header.Height - 5); };
        return header;
    }

    private Panel DeviceCard(string heading, string subtitle, Label value, string action, EDataFlow flow)
    {
        var card = new Panel { Dock = DockStyle.Fill, BackColor = Surface, Margin = new Padding(0, 0, 10, 0), Padding = new Padding(14) };
        var table = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4 };
        table.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        table.RowStyles.Add(new RowStyle(SizeType.Absolute, 26));
        table.RowStyles.Add(new RowStyle(SizeType.Absolute, 25));
        table.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        table.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));
        table.Controls.Add(new Label { Text = heading, ForeColor = Accent, Font = new Font("Segoe UI", 10, FontStyle.Bold), Dock = DockStyle.Fill }, 0, 0);
        table.Controls.Add(new Label { Text = subtitle, ForeColor = Muted, Dock = DockStyle.Fill }, 0, 1);
        table.Controls.Add(value, 0, 2);
        var button = ActionButton(action, true);
        button.Width = 210;
        button.Dock = DockStyle.Left;
        button.Click += (_, _) =>
        {
            try
            {
                if (!AppModel.Instance.CycleActiveDevice(flow)) throw new InvalidOperationException("Keine weiteren konfigurierten Geräte verfügbar.");
                RefreshDevices();
                _status.Text = "Audiogerät gewechselt";
            }
            catch (Exception ex) { ShowError(ex); }
        };
        table.Controls.Add(button, 0, 3);
        card.Controls.Add(table);
        return card;
    }

    private static Label DeviceLabel() => new()
    {
        Text = "Wird ermittelt ...",
        Dock = DockStyle.Fill,
        ForeColor = Foreground,
        Font = new Font("Segoe UI", 13, FontStyle.Bold),
        TextAlign = ContentAlignment.MiddleLeft,
        AutoEllipsis = true
    };

    private static Button ActionButton(string caption, bool accent)
    {
        var button = new Button { Text = caption, Dock = DockStyle.Fill, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand, Font = new Font("Segoe UI", 9.5f, FontStyle.Bold), ForeColor = Foreground, BackColor = accent ? Accent : Surface, Margin = new Padding(3), AutoEllipsis = true };
        button.FlatAppearance.BorderColor = Accent;
        return button;
    }

    private void RefreshDevices()
    {
        _output.Text = CurrentDevice(EDataFlow.eRender);
        _input.Text = CurrentDevice(EDataFlow.eCapture);
        try
        {
            var state = AppModel.Instance.GetMicrophoneMuteState();
            _mute.Enabled = state != null;
            _mute.Text = state?.IsMuted == true ? "Mikrofon einschalten" : "Mikrofon stumm";
        }
        catch { _mute.Enabled = false; _mute.Text = "Mikrofon nicht verfügbar"; }
    }

    private static string CurrentDevice(EDataFlow flow)
    {
        try
        {
            using var device = AudioSwitcher.Instance.GetDefaultAudioEndpoint(flow, ERole.eMultimedia);
            return device?.NameClean ?? "Kein Gerät ausgewählt";
        }
        catch { return "Nicht verfügbar"; }
    }

    private void RefreshProfiles()
    {
        _profiles.SuspendLayout();
        try
        {
            _profiles.Controls.Clear();
            foreach (var profile in AppModel.Instance.ProfileManager.Profiles.OrderBy(p => p.Name))
            {
                var chosen = profile;
                var button = ActionButton(profile.Name, false);
                button.Dock = DockStyle.None;
                button.Width = Math.Min(235, Math.Max(125, profile.Name.Length * 9 + 25));
                button.Height = 39;
                button.Click += (_, _) =>
                {
                    try
                    {
                        AppModel.Instance.ProfileManager.SwitchAudio(chosen);
                        RefreshDevices();
                        _status.Text = "Profil aktiv: " + chosen.Name;
                    }
                    catch (Exception ex) { ShowError(ex); }
                };
                _profiles.Controls.Add(button);
            }
            if (_profiles.Controls.Count == 0)
                _profiles.Controls.Add(new Label { Text = "Noch keine Profile vorhanden. Bitte in den Audio-Einstellungen anlegen.", ForeColor = Muted, AutoSize = true });
        }
        finally { _profiles.ResumeLayout(); }
    }

    private void ShowError(Exception error)
    {
        _status.Text = "Aktion fehlgeschlagen";
        MessageBox.Show(this, error.Message, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
    }
}
