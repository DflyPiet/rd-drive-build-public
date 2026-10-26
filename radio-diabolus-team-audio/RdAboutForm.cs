using System;
using System.Drawing;
using System.Windows.Forms;
using SoundSwitch.Properties;

namespace SoundSwitch.UI.Forms;

/// <summary>Radio Diabolus branding window. Original author notices remain in LICENSE.txt.</summary>
public sealed class RdAboutForm : Form
{
    private static Bitmap CreateHighResolutionLogo()
    {
        using var icon = new Icon(Resources.Switch_SoundWave, new Size(128, 128));
        return icon.ToBitmap();
    }

    public RdAboutForm()
    {
        Text = "Über RD Soundtool";
        Icon = Resources.Switch_SoundWave;
        BackColor = Color.FromArgb(20, 20, 24);
        ForeColor = Color.FromArgb(241, 240, 242);
        Font = new Font("Segoe UI", 10);
        ClientSize = new Size(465, 315);
        MinimumSize = MaximumSize = new Size(481, 354);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;

        var logo = new PictureBox
        {
            Location = new Point(19, 23),
            Size = new Size(90, 90),
            Image = CreateHighResolutionLogo(),
            SizeMode = PictureBoxSizeMode.Zoom
        };
        Controls.Add(logo);
        Disposed += (_, _) => logo.Image?.Dispose();
        Controls.Add(new Label
        {
            Text = "RADIO DIABOLUS",
            Location = new Point(122, 21),
            Size = new Size(323, 41),
            ForeColor = Color.White,
            Font = new Font("Segoe UI", 21, FontStyle.Bold)
        });
        Controls.Add(new Label
        {
            Text = "RD Soundtool",
            Location = new Point(124, 72),
            Size = new Size(300, 29),
            ForeColor = Color.FromArgb(231, 47, 65),
            Font = new Font("Segoe UI", 15, FontStyle.Bold)
        });
        var panel = new Panel
        {
            Location = new Point(19, 131),
            Size = new Size(428, 162),
            BackColor = Color.FromArgb(35, 35, 42)
        };
        panel.Controls.Add(new Label
        {
            Text = "Radio Diabolus Edition  |  Version " + Application.ProductVersion,
            Location = new Point(13, 15),
            Size = new Size(405, 28),
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            ForeColor = Color.White
        });
        panel.Controls.Add(new Label
        {
            Text = "Private Windows-Audiosteuerung für Radio Diabolus.\n" +
                   "Wiedergabe, Mikrofone und Audioprofile.",
            Location = new Point(13, 58),
            Size = new Size(407, 54),
            ForeColor = Color.FromArgb(223, 223, 229)
        });
        panel.Controls.Add(new Label
        {
            Text = "Basis: SoundSwitch (GPLv3). Urheber- und Lizenzhinweise\n" +
                   "stehen in LICENSE.txt und den Quellcodedateien.",
            Location = new Point(13, 115),
            Size = new Size(402, 42),
            ForeColor = Color.FromArgb(159, 159, 167),
            Font = new Font("Segoe UI", 8.8f)
        });
        Controls.Add(panel);
    }
}
