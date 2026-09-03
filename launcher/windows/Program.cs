using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text.Json;
using System.Drawing;
using System.Windows.Forms;

namespace InfiniteAscensionLauncher;

internal static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new LauncherForm());
    }
}

internal sealed class LauncherForm : Form
{
    private const string ManifestUrl = "https://github.com/Mataiasu/Infinite-Ascension/releases/download/latest/manifest.json";
    private const string GameExe = "InfiniteAscension.exe";

    private readonly HttpClient http = new() { Timeout = TimeSpan.FromMinutes(10) };
    private readonly Label status = new();
    private readonly Label version = new();
    private readonly ProgressBar progress = new();
    private readonly Button play = new();
    private readonly Button update = new();
    private bool busy;

    private string RootDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InfiniteAscension");
    private string GameDir => Path.Combine(RootDir, "Game");
    private string StatePath => Path.Combine(RootDir, "launcher_state.json");
    private string GamePath => Path.Combine(GameDir, GameExe);

    public LauncherForm()
    {
        Text = "Infinite Ascension Launcher";
        ClientSize = new Size(660, 440);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = Color.FromArgb(9, 12, 21);
        ForeColor = Color.White;
        StartPosition = FormStartPosition.CenterScreen;

        var title = new Label
        {
            Text = "INFINITE ASCENSION",
            Font = new Font("Segoe UI", 24, FontStyle.Bold),
            ForeColor = Color.FromArgb(241, 239, 255),
            BackColor = BackColor,
            AutoSize = true,
            Location = new Point(150, 32)
        };
        Controls.Add(title);

        var subtitle = new Label
        {
            Text = "LAUNCHER",
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            ForeColor = Color.FromArgb(166, 108, 255),
            BackColor = BackColor,
            AutoSize = true,
            Location = new Point(275, 72)
        };
        Controls.Add(subtitle);

        version.Text = "Build locale : #0";
        version.Font = new Font("Segoe UI", 10);
        version.ForeColor = Color.FromArgb(168, 177, 202);
        version.BackColor = BackColor;
        version.AutoSize = true;
        version.Location = new Point(220, 112);
        Controls.Add(version);

        status.Text = "Vérification des mises à jour…";
        status.Font = new Font("Segoe UI", 10);
        status.ForeColor = Color.FromArgb(217, 222, 241);
        status.BackColor = BackColor;
        status.TextAlign = ContentAlignment.MiddleCenter;
        status.Size = new Size(580, 48);
        status.Location = new Point(40, 140);
        Controls.Add(status);

        progress.Minimum = 0;
        progress.Maximum = 100;
        progress.Style = ProgressBarStyle.Continuous;
        progress.Size = new Size(520, 20);
        progress.Location = new Point(70, 205);
        Controls.Add(progress);

        play.Text = "▶  JOUER";
        play.Font = new Font("Segoe UI", 11, FontStyle.Bold);
        play.ForeColor = Color.White;
        play.BackColor = Color.FromArgb(110, 67, 191);
        play.FlatStyle = FlatStyle.Flat;
        play.Size = new Size(220, 58);
        play.Location = new Point(75, 250);
        play.Click += (_, _) => PlayGame();
        Controls.Add(play);

        update.Text = "↻  METTRE À JOUR";
        update.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        update.ForeColor = Color.White;
        update.BackColor = Color.FromArgb(32, 41, 64);
        update.FlatStyle = FlatStyle.Flat;
        update.Size = new Size(220, 58);
        update.Location = new Point(365, 250);
        update.Click += async (_, _) => await CheckAndUpdateAsync(true);
        Controls.Add(update);

        var footer = new Label
        {
            Text = "Vérification automatique à chaque ouverture.\nLes mises à jour sont installées dans AppData\\Local.",
            Font = new Font("Segoe UI", 9),
            ForeColor = Color.FromArgb(104, 115, 143),
            BackColor = BackColor,
            TextAlign = ContentAlignment.MiddleCenter,
            Size = new Size(620, 50),
            Location = new Point(20, 350)
        };
        Controls.Add(footer);

        Shown += async (_, _) => await CheckAndUpdateAsync(false);
    }

    private int LocalBuild()
    {
        try
        {
            if (!File.Exists(StatePath)) return 0;
            using var doc = JsonDocument.Parse(File.ReadAllText(StatePath));
            return doc.RootElement.GetProperty("build").GetInt32();
        }
        catch
        {
            return 0;
        }
    }

    private async Task<JsonDocument> GetManifestAsync()
    {
        var url = $"{ManifestUrl}?t={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/3.0");
        request.Headers.CacheControl = new System.Net.Http.Headers.CacheControlHeaderValue { NoCache = true };
        using var response = await http.SendAsync(request);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync();
        return await JsonDocument.ParseAsync(stream);
    }

    private async Task CheckAndUpdateAsync(bool manual)
    {
        if (busy) return;
        busy = true;
        SetButtons(false);
        progress.Value = 0;

        try
        {
            Directory.CreateDirectory(RootDir);
            Directory.CreateDirectory(GameDir);

            var local = LocalBuild();
            version.Text = $"Build locale : #{local}";

            using var manifest = await GetManifestAsync();
            var root = manifest.RootElement;
            var remote = root.GetProperty("build").GetInt32();
            var asset = root.GetProperty("assets").GetProperty("windows");
            var url = asset.GetProperty("url").GetString() ?? throw new InvalidOperationException("URL Windows absente du manifeste.");
            var expectedSha = asset.GetProperty("sha256").GetString() ?? throw new InvalidOperationException("SHA-256 Windows absente du manifeste.");

            version.Text = $"Build locale : #{local}   ·   Disponible : #{remote}";

            if (!File.Exists(GamePath) || remote > local)
            {
                await InstallGameAsync(url, expectedSha, remote, root.TryGetProperty("commit", out var commitElement) ? commitElement.GetString() ?? "" : "");
                status.Text = $"Jeu à jour — build #{remote}.";
                progress.Value = 100;
            }
            else
            {
                status.Text = manual ? "Jeu déjà à jour." : "Jeu déjà à jour. Prêt à jouer.";
                progress.Value = 100;
            }
        }
        catch (Exception ex)
        {
            status.Text = File.Exists(GamePath)
                ? $"Mise à jour indisponible : {ex.Message}\nLa version locale peut être lancée."
                : $"Installation impossible : {ex.Message}";
            progress.Value = 0;
        }
        finally
        {
            busy = false;
            SetButtons(true);
        }
    }

    private async Task InstallGameAsync(string url, string expectedSha, int build, string commit)
    {
        if (Process.GetProcessesByName(Path.GetFileNameWithoutExtension(GameExe)).Length > 0)
            throw new InvalidOperationException("Le jeu est actuellement lancé. Fermez-le avant de le mettre à jour.");

        var tempRoot = Path.Combine(Path.GetTempPath(), "InfiniteAscensionUpdate", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(tempRoot);
        var archive = Path.Combine(tempRoot, "game.zip");
        var unpack = Path.Combine(tempRoot, "game");
        Directory.CreateDirectory(unpack);

        try
        {
            status.Text = "Téléchargement de la mise à jour…";
            progress.Value = 0;

            using (var request = new HttpRequestMessage(HttpMethod.Get, url))
            {
                request.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/3.0");
                using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();

                var total = response.Content.Headers.ContentLength ?? 0;
                await using var source = await response.Content.ReadAsStreamAsync();
                await using var target = new FileStream(archive, FileMode.Create, FileAccess.Write, FileShare.None, 1024 * 1024, useAsync: true);
                var buffer = new byte[1024 * 1024];
                long done = 0;
                int read;
                while ((read = await source.ReadAsync(buffer.AsMemory(0, buffer.Length))) > 0)
                {
                    await target.WriteAsync(buffer.AsMemory(0, read));
                    done += read;
                    if (total > 0)
                        progress.Value = (int)Math.Clamp(done * 100L / total, 0, 100);
                }
                await target.FlushAsync();
            }

            status.Text = "Vérification SHA-256…";
            string actualSha;
            await using (var shaStream = new FileStream(archive, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
                actualSha = Convert.ToHexString(await SHA256.HashDataAsync(shaStream)).ToLowerInvariant();
            }

            if (!actualSha.Equals(expectedSha, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("La vérification SHA-256 a échoué.");

            status.Text = "Extraction de la mise à jour…";
            ZipFile.ExtractToDirectory(archive, unpack, true);
            var extractedGame = Path.Combine(unpack, GameExe);
            if (!File.Exists(extractedGame))
                throw new InvalidOperationException("L'exécutable du jeu est absent du package.");

            status.Text = "Installation de la mise à jour…";
            foreach (var file in Directory.GetFiles(unpack, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(unpack, file);
                var destination = Path.Combine(GameDir, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                File.Copy(file, destination, true);
            }

            var stateJson = JsonSerializer.Serialize(new { build, commit }, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(StatePath, stateJson);
        }
        finally
        {
            try { Directory.Delete(tempRoot, true); } catch { }
        }
    }

    private void PlayGame()
    {
        try
        {
            if (!File.Exists(GamePath))
            {
                status.Text = "Le jeu n'est pas encore installé. Utilisez METTRE À JOUR.";
                return;
            }

            Process.Start(new ProcessStartInfo
            {
                FileName = GamePath,
                WorkingDirectory = GameDir,
                UseShellExecute = true
            });
            Close();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "Infinite Ascension", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void SetButtons(bool enabled)
    {
        play.Enabled = enabled;
        update.Enabled = enabled;
    }
}
