using System;
using System.Drawing;
using System.Globalization;
using System.Windows.Forms;
using SoundSwitch.Properties;
using SoundSwitch.Localization;

namespace SoundSwitch.UI.Forms;

public sealed partial class SettingsForm
{
    // Radio Diabolus layout-only adjustments. Audio settings and their event handlers stay untouched.
    private void ApplyRdBranding()
    {
        Icon = Resources.Switch_SoundWave;
        Text = "RD Soundtool | " + SettingsStrings.settings;

        // There is no upstream automatic update for private Radio Diabolus releases.
        // Do not disable the entire form: disabled child controls become unreadable in dark mode.
        updateSettingsGroupBox.Visible = false;
        languageGroupBox.Location = new Point(359, 3);
        languageGroupBox.Width = 300;

        var darkSurface = Color.FromArgb(31, 32, 39);
        var foreground = Color.FromArgb(237, 237, 241);
        var secondary = Color.FromArgb(188, 189, 198);
        var red = Color.FromArgb(235, 59, 79);
        var statusGroup = new GroupBox
        {
            Text = "Radio Diabolus",
            Name = "rdBuildInfoGroup",
            ForeColor = foreground,
            BackColor = darkSurface,
            Location = new Point(359, 77),
            Size = new Size(300, 149),
            Anchor = AnchorStyles.Top | AnchorStyles.Right,
            Padding = new Padding(10)
        };
        statusGroup.Controls.Add(new Label
        {
            Text = "RD Soundtool",
            ForeColor = red,
            Font = new Font("Segoe UI", 13f, FontStyle.Bold),
            Location = new Point(14, 24),
            Size = new Size(266, 32)
        });
        statusGroup.Controls.Add(new Label
        {
            Text = "Radio Diabolus Edition " + Application.ProductVersion +
                   Environment.NewLine + "Lokale Audiosteuerung" +
                   Environment.NewLine + "Automatische Updates deaktiviert",
            ForeColor = secondary,
            Font = new Font("Segoe UI", 9f),
            Location = new Point(15, 67),
            Size = new Size(269, 65),
            AutoEllipsis = false
        });
        appSettingTabPage.Controls.Add(statusGroup);

        // Keep export/reset/import functional but remove unrelated upstream support prompts.
        troubleshootingLabel.Visible = false;
        gitHubHelpLinkLabel.Visible = false;
        discordCommunityLinkLabel.Visible = false;
        donateLinkLabel.Visible = false;
        exportLogFilesLabel.Text = CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "de"
            ? "Erstellt ein ZIP-Archiv mit lokalen Protokollen zur Fehlersuche. Es wird nichts automatisch versendet."
            : "Creates a ZIP archive of local logs for troubleshooting. Nothing is uploaded automatically.";

        // The stock control paints icon and text within the same 236px label.
        // Separate them to prevent text/logo collision at any display scale.
        appNameLabel.Visible = false;
        var footer = new Panel
        {
            Name = "rdTroubleshootingFooter",
            Location = new Point(8, 245),
            Size = new Size(646, 107),
            Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right,
            BackColor = darkSurface
        };
        var art = new PictureBox
        {
            Location = new Point(13, 12),
            Size = new Size(82, 82),
            SizeMode = PictureBoxSizeMode.Zoom,
            BackColor = Color.FromArgb(13, 13, 15)
        };
        using (var icon = new Icon(Resources.Switch_SoundWave, new Size(128, 128)))
        {
            art.Image = icon.ToBitmap();
        }
        footer.Controls.Add(art);
        Disposed += (_, _) => art.Image?.Dispose();

        footer.Controls.Add(new Label
        {
            Text = "RD Soundtool",
            ForeColor = foreground,
            Font = new Font("Segoe UI", 20f, FontStyle.Bold),
            Location = new Point(117, 20),
            Size = new Size(496, 43),
            TextAlign = ContentAlignment.MiddleLeft,
            AutoEllipsis = true,
            Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
        });
        footer.Controls.Add(new Label
        {
            Text = "RADIO DIABOLUS   |   Version " + Application.ProductVersion,
            ForeColor = red,
            Font = new Font("Segoe UI", 10f, FontStyle.Bold),
            Location = new Point(119, 69),
            Size = new Size(490, 23),
            Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
        });
        troubleshootingTabPage.Controls.Add(footer);
    }
}
