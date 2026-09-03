using System.Diagnostics;
using System.Drawing;
using System.IO.Compression;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Windows.Forms;

namespace InfiniteAscensionLauncher;

internal static class LauncherMain
{
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new LauncherFormV2());
    }
}

internal sealed class LauncherFormV2 : Form
{
    private const string ManifestUrl = "https://github.com/Mataiasu/Infinite-Ascension/releases/download/latest/manifest.json";
    private const string GameExe = "InfiniteAscension.exe";

    private readonly HttpClient http = new() { Timeout = TimeSpan.FromMinutes(10) };
    private readonly Label status = new();
    private readonly Label version = new();
    private readonly ProgressBar progress = new();
    private readonly Button play = new();
    private readonly Button update = new();
    private readonly Button logs = new();
    private bool busy;

    private string RootDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InfiniteAscension");
    private string GameDir => Path.Combine(RootDir, "Game");
    private string LogsDir => Path.Combine(RootDir, "Logs");
    private string StatePath => Path.Combine(RootDir, "launcher_state.json");
    private string GamePath => Path.Combine(GameDir, GameExe);
    private string LauncherLog => Path.Combine(LogsDir, "launcher.log");
    private string GameLog => Path.Combine(LogsDir, "game.log");

    public LauncherFormV2()
    {
        Text = "Infinite Ascension Launcher";
        ClientSize = new Size(700, 470);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(9, 12, 21);
        ForeColor = Color.White;

        var title = MakeLabel("INFINITE ASCENSION", new Font("Segoe UI", 24, FontStyle.Bold), Color.FromArgb(241, 239, 255), 160, 28, 380, 40);
        Controls.Add(title);
        var subtitle = MakeLabel("LAUNCHER", new Font("Segoe UI", 11, FontStyle.Bold), Color.FromArgb(166, 108, 255), 300, 68, 120, 25);
        Controls.Add(subtitle);

        version.Text = "Build locale : #0";
        version.Font = new Font("Segoe UI", 10);
        version.ForeColor = Color.FromArgb(168, 177, 202);
        version.BackColor = BackColor;
        version.TextAlign = ContentAlignment.MiddleCenter;
        version.Size = new Size(650, 28);
        version.Location = new Point(25, 100);
        Controls.Add(version);

        status.Text = "Vérification des mises à jour…";
        status.Font = new Font("Segoe UI", 10);
        status.ForeColor = Color.FromArgb(217, 222, 241);
        status.BackColor = BackColor;
        status.TextAlign = ContentAlignment.MiddleCenter;
        status.Size = new Size(650, 55);
        status.Location = new Point(25, 132);
        Controls.Add(status);

        progress.Minimum = 0;
        progress.Maximum = 100;
        progress.Size = new Size(540, 18);
        progress.Location = new Point(80, 195);
        Controls.Add(progress);

        ConfigureButton(play, "▶  JOUER", 75, 235, 170, 58);
        play.Click += (_, _) => PlayGame();
        Controls.Add(play);

        ConfigureButton(update, "↻  METTRE À JOUR", 265, 235, 205, 58);
        update.Click += async (_, _) => await CheckAndUpdateAsync(true);
        Controls.Add(update);

        ConfigureButton(logs, "▣  JOURNAUX", 490, 235, 135, 58);
        logs.Click += (_, _) => OpenLogs();
        Controls.Add(logs);

        var footer = MakeLabel(
            "Vérification automatique à chaque ouverture.\nLes pushes publiés produisent une nouvelle build.",
            new Font("Segoe UI", 9), Color.FromArgb(104, 115, 143), 40, 330, 620, 48);
        footer.TextAlign = ContentAlignment.MiddleCenter;
        Controls.Add(footer);

        var path = MakeLabel($"Installation : {GameDir}", new Font("Segoe UI", 8), Color.FromArgb(78, 88, 114), 30, 390, 640, 22);
        path.TextAlign = ContentAlignment.MiddleCenter;
        Controls.Add(path);

        Shown += async (_, _) => await CheckAndUpdateAsync(false);
    }

    private Label MakeLabel(string text, Font font, Color color, int x, int y, int w, int h)
    {
        return new Label { Text = text, Font = font, ForeColor = color, BackColor = BackColor, Location = new Point(x, y), Size = new Size(w, h), AutoSize = false };
    }

    private void ConfigureButton(Button b, string text, int x, int y, int w, int h)
    {
        b.Text = text;
        b.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        b.ForeColor = Color.White;
        b.BackColor = Color.FromArgb(32, 41, 64);
        b.FlatStyle = FlatStyle.Flat;
        b.FlatAppearance.BorderSize = 1;
        b.Size = new Size(w, h);
        b.Location = new Point(x, y);
        b.TabStop = false;
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        http.Dispose();
        base.OnFormClosed(e);
    }

    private void Log(string message)
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            File.AppendAllText(LauncherLog, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] {message}{Environment.NewLine}", Encoding.UTF8);
        }
        catch { }
    }

    private int LocalBuild()
    {
        try
        {
            if (!File.Exists(StatePath)) return 0;
            using var doc = JsonDocument.Parse(File.ReadAllText(StatePath));
            return doc.RootElement.GetProperty("build").GetInt32();
        }
        catch { return 0; }
    }

    private async Task<JsonDocument> GetManifestAsync()
    {
        string url = $"{ManifestUrl}?t={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/5.0");
        req.Headers.CacheControl = new CacheControlHeaderValue { NoCache = true };
        Log($"Lecture du manifeste : {url}");
        using var response = await http.SendAsync(req);
        response.EnsureSuccessStatusCode();
        await using var stream = await response.Content.ReadAsStreamAsync();
        return await JsonDocument.ParseAsync(stream);
    }

    private async Task CheckAndUpdateAsync(bool manual)
    {
        if (busy) return;
        busy = true;
        SetButtons(false);
        try
        {
            Directory.CreateDirectory(GameDir);
            Directory.CreateDirectory(LogsDir);
            int local = LocalBuild();
            using var manifest = await GetManifestAsync();
            JsonElement root = manifest.RootElement;
            int remote = root.GetProperty("build").GetInt32();
            JsonElement asset = root.GetProperty("assets").GetProperty("windows");
            string url = asset.GetProperty("url").GetString() ?? throw new InvalidOperationException("URL Windows absente.");
            string expectedSha = asset.GetProperty("sha256").GetString() ?? throw new InvalidOperationException("SHA-256 Windows absente.");
            version.Text = $"Build locale : #{local}   ·   Disponible : #{remote}";
            Log($"Build locale={local}, distante={remote}");

            if (!File.Exists(GamePath) || remote > local)
            {
                await InstallGameAsync(url, expectedSha, remote, root.TryGetProperty("commit", out JsonElement c) ? c.GetString() ?? "" : "");
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
            Log($"ERREUR mise à jour : {ex}");
            status.Text = File.Exists(GamePath) ? $"Mise à jour indisponible. Voir les journaux." : $"Installation impossible. Voir les journaux.";
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
            throw new InvalidOperationException("Le jeu est actuellement lancé. Fermez-le avant la mise à jour.");

        string tempRoot = Path.Combine(Path.GetTempPath(), "InfiniteAscensionUpdate", Guid.NewGuid().ToString("N"));
        string archive = Path.Combine(tempRoot, "game.zip");
        string unpack = Path.Combine(tempRoot, "game");
        Directory.CreateDirectory(unpack);
        try
        {
            status.Text = "Téléchargement de la mise à jour…";
            using (var req = new HttpRequestMessage(HttpMethod.Get, url))
            {
                req.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/5.0");
                using var response = await http.SendAsync(req, HttpCompletionOption.ResponseHeadersRead);
                response.EnsureSuccessStatusCode();
                long total = response.Content.Headers.ContentLength ?? 0;
                await using var source = await response.Content.ReadAsStreamAsync();
                await using var target = new FileStream(archive, FileMode.Create, FileAccess.Write, FileShare.None, 1024 * 1024, true);
                var buffer = new byte[1024 * 1024];
                long done = 0;
                int read;
                while ((read = await source.ReadAsync(buffer.AsMemory(0, buffer.Length))) > 0)
                {
                    await target.WriteAsync(buffer.AsMemory(0, read));
                    done += read;
                    if (total > 0) progress.Value = (int)Math.Clamp(done * 100L / total, 0, 100);
                }
                await target.FlushAsync();
            }

            status.Text = "Vérification SHA-256…";
            string actualSha;
            await using (var shaStream = new FileStream(archive, FileMode.Open, FileAccess.Read, FileShare.Read))
                actualSha = Convert.ToHexString(await SHA256.HashDataAsync(shaStream)).ToLowerInvariant();
            if (!actualSha.Equals(expectedSha, StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("La vérification SHA-256 a échoué.");

            status.Text = "Extraction…";
            ZipFile.ExtractToDirectory(archive, unpack, true);
            string extractedGame = Path.Combine(unpack, GameExe);
            if (!File.Exists(extractedGame))
                throw new InvalidOperationException("InfiniteAscension.exe est absent du package.");

            status.Text = "Installation…";
            foreach (string file in Directory.GetFiles(unpack, "*", SearchOption.AllDirectories))
            {
                string relative = Path.GetRelativePath(unpack, file);
                string destination = Path.Combine(GameDir, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                File.Copy(file, destination, true);
            }
            File.WriteAllText(StatePath, JsonSerializer.Serialize(new { build, commit }, new JsonSerializerOptions { WriteIndented = true }), Encoding.UTF8);
            Log($"Installation réussie : build={build}, commit={commit}");
        }
        finally
        {
            try { Directory.Delete(tempRoot, true); } catch (Exception ex) { Log($"Nettoyage temp incomplet : {ex.Message}"); }
        }
    }

    private void PlayGame()
    {
        if (busy) return;
        if (!File.Exists(GamePath))
        {
            status.Text = "Jeu non installé. Utilisez METTRE À JOUR.";
            return;
        }
        try
        {
            File.WriteAllText(GameLog, $"=== Infinite Ascension game log {DateTime.Now:yyyy-MM-dd HH:mm:ss} ==={Environment.NewLine}", Encoding.UTF8);
            Log($"Lancement du jeu : {GamePath}");
            var psi = new ProcessStartInfo
            {
                FileName = GamePath,
                WorkingDirectory = GameDir,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                StandardOutputEncoding = Encoding.UTF8,
                StandardErrorEncoding = Encoding.UTF8
            };
            var process = new Process { StartInfo = psi, EnableRaisingEvents = true };
            if (!process.Start()) throw new InvalidOperationException("Impossible de lancer le jeu.");
            process.OutputDataReceived += (_, e) => { if (e.Data != null) LogGame("STDOUT", e.Data); };
            process.ErrorDataReceived += (_, e) => { if (e.Data != null) LogGame("STDERR", e.Data); };
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            _ = Task.Run(async () =>
            {
                try
                {
                    await process.WaitForExitAsync();
                    int exitCode = process.ExitCode;
                    Log($"Jeu terminé avec code {exitCode}.");
                    BeginInvoke(() => status.Text = exitCode == 0 ? "Jeu terminé normalement." : $"Jeu fermé avec code {exitCode}. Voir JOURNAUX.");
                }
                catch (Exception ex)
                {
                    Log($"ERREUR suivi du jeu : {ex}");
                }
                finally
                {
                    process.Dispose();
                }
            });
            Close();
        }
        catch (Exception ex)
        {
            Log($"ERREUR lancement jeu : {ex}");
            MessageBox.Show(ex.Message, "Infinite Ascension", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private void LogGame(string stream, string message)
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            File.AppendAllText(GameLog, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] [{stream}] {message}{Environment.NewLine}", Encoding.UTF8);
        }
        catch { }
    }

    private void OpenLogs()
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            Process.Start(new ProcessStartInfo { FileName = "explorer.exe", Arguments = $"\"{LogsDir}\"", UseShellExecute = true });
        }
        catch (Exception ex) { MessageBox.Show(ex.Message, "Infinite Ascension", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }

    private void SetButtons(bool enabled)
    {
        play.Enabled = enabled;
        update.Enabled = enabled;
        logs.Enabled = enabled;
    }
}
