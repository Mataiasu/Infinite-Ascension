using System.Diagnostics;
using System.Drawing;
using System.IO.Compression;
using System.Net.Http;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Windows.Forms;

namespace InfiniteAscensionLauncher;

internal static class Program
{
    [STAThread]
    private static void Main()
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
    private readonly Button logs = new();
    private bool busy;

    private string RootDir => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InfiniteAscension");
    private string GameDir => Path.Combine(RootDir, "Game");
    private string StatePath => Path.Combine(RootDir, "launcher_state.json");
    private string GamePath => Path.Combine(GameDir, GameExe);
    private string LogsDir => Path.Combine(RootDir, "Logs");
    private string LauncherLog => Path.Combine(LogsDir, "launcher.log");
    private string GameLog => Path.Combine(LogsDir, "game.log");
    private string LogEndpointPath => Path.Combine(RootDir, "log_endpoint.txt");

    public LauncherForm()
    {
        Text = "Infinite Ascension Launcher";
        ClientSize = new Size(700, 470);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = Color.FromArgb(9, 12, 21);
        ForeColor = Color.White;
        StartPosition = FormStartPosition.CenterScreen;

        Directory.CreateDirectory(LogsDir);
        LogLauncher("Launcher démarré.");

        var title = new Label
        {
            Text = "INFINITE ASCENSION",
            Font = new Font("Segoe UI", 24, FontStyle.Bold),
            ForeColor = Color.FromArgb(241, 239, 255),
            BackColor = BackColor,
            AutoSize = true,
            Location = new Point(170, 28)
        };
        Controls.Add(title);

        var subtitle = new Label
        {
            Text = "LAUNCHER",
            Font = new Font("Segoe UI", 11, FontStyle.Bold),
            ForeColor = Color.FromArgb(166, 108, 255),
            BackColor = BackColor,
            AutoSize = true,
            Location = new Point(296, 69)
        };
        Controls.Add(subtitle);

        version.Text = "Build locale : #0";
        version.Font = new Font("Segoe UI", 10);
        version.ForeColor = Color.FromArgb(168, 177, 202);
        version.BackColor = BackColor;
        version.AutoSize = true;
        version.Location = new Point(220, 108);
        Controls.Add(version);

        status.Text = "Vérification des mises à jour…";
        status.Font = new Font("Segoe UI", 10);
        status.ForeColor = Color.FromArgb(217, 222, 241);
        status.BackColor = BackColor;
        status.TextAlign = ContentAlignment.MiddleCenter;
        status.Size = new Size(620, 54);
        status.Location = new Point(40, 138);
        Controls.Add(status);

        progress.Minimum = 0;
        progress.Maximum = 100;
        progress.Style = ProgressBarStyle.Continuous;
        progress.Size = new Size(560, 20);
        progress.Location = new Point(70, 200);
        Controls.Add(progress);

        ConfigureButton(play, "▶  JOUER", new Point(60, 247), Color.FromArgb(110, 67, 191));
        play.Click += (_, _) => PlayGame();

        ConfigureButton(update, "↻  METTRE À JOUR", new Point(300, 247), Color.FromArgb(32, 41, 64));
        update.Click += async (_, _) => await CheckAndUpdateAsync(true);

        ConfigureButton(logs, "▣  JOURNAUX", new Point(540, 247), Color.FromArgb(38, 47, 70));
        logs.Size = new Size(100, 58);
        logs.Font = new Font("Segoe UI", 9, FontStyle.Bold);
        logs.Click += (_, _) => OpenLogs();

        var footer = new Label
        {
            Text = "Vérification automatique à chaque ouverture.\nLes erreurs du jeu et du launcher sont enregistrées automatiquement.",
            Font = new Font("Segoe UI", 9),
            ForeColor = Color.FromArgb(104, 115, 143),
            BackColor = BackColor,
            TextAlign = ContentAlignment.MiddleCenter,
            Size = new Size(660, 55),
            Location = new Point(20, 350)
        };
        Controls.Add(footer);

        Shown += async (_, _) => await CheckAndUpdateAsync(false);
    }

    private void ConfigureButton(Button button, string text, Point location, Color backColor)
    {
        button.Text = text;
        button.Font = new Font("Segoe UI", 10, FontStyle.Bold);
        button.ForeColor = Color.White;
        button.BackColor = backColor;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderColor = Color.FromArgb(225, 226, 238);
        button.FlatAppearance.BorderSize = 1;
        button.Size = new Size(220, 58);
        button.Location = location;
        Controls.Add(button);
    }

    private void LogLauncher(string message)
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            File.AppendAllText(LauncherLog, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] {message}{Environment.NewLine}", Encoding.UTF8);
        }
        catch { }
    }

    private void LogGame(string stream, string line)
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            File.AppendAllText(GameLog, $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}] [{stream}] {line}{Environment.NewLine}", Encoding.UTF8);
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
        var url = $"{ManifestUrl}?t={DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/5.0");
        request.Headers.CacheControl = new System.Net.Http.Headers.CacheControlHeaderValue { NoCache = true };
        LogLauncher($"Lecture du manifeste : {url}");
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
            Directory.CreateDirectory(LogsDir);

            var local = LocalBuild();
            using var manifest = await GetManifestAsync();
            var root = manifest.RootElement;
            var remote = root.GetProperty("build").GetInt32();
            var asset = root.GetProperty("assets").GetProperty("windows");
            var url = asset.GetProperty("url").GetString() ?? throw new InvalidOperationException("URL Windows absente.");
            var expectedSha = asset.GetProperty("sha256").GetString() ?? throw new InvalidOperationException("SHA-256 Windows absente.");

            version.Text = $"Build locale : #{local}   ·   Disponible : #{remote}";
            LogLauncher($"Build locale={local}, distante={remote}");

            if (!File.Exists(GamePath) || remote > local)
            {
                await InstallGameAsync(url, expectedSha, remote, root.TryGetProperty("commit", out var commit) ? commit.GetString() ?? "" : "");
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
            LogLauncher($"ERREUR CheckAndUpdate : {ex}");
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
            throw new InvalidOperationException("Le jeu est actuellement lancé. Fermez-le avant la mise à jour.");

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
                request.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/5.0");
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
                    if (total > 0) progress.Value = (int)Math.Clamp(done * 100L / total, 0, 100);
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
                throw new InvalidOperationException("InfiniteAscension.exe est absent du package.");

            status.Text = "Installation de la mise à jour…";
            foreach (var file in Directory.GetFiles(unpack, "*", SearchOption.AllDirectories))
            {
                var relative = Path.GetRelativePath(unpack, file);
                var destination = Path.Combine(GameDir, relative);
                Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                File.Copy(file, destination, true);
            }

            File.WriteAllText(StatePath, JsonSerializer.Serialize(new { build, commit }, new JsonSerializerOptions { WriteIndented = true }), Encoding.UTF8);
            LogLauncher($"Installation réussie : build={build}, commit={commit}");
        }
        finally
        {
            try { Directory.Delete(tempRoot, true); } catch (Exception ex) { LogLauncher($"Nettoyage temp incomplet : {ex.Message}"); }
        }
    }

    private void PlayGame()
    {
        if (busy) return;
        if (!File.Exists(GamePath))
        {
            status.Text = "Le jeu n'est pas installé. Utilisez METTRE À JOUR.";
            return;
        }

        try
        {
            File.WriteAllText(GameLog, $"=== Infinite Ascension game log {DateTime.Now:yyyy-MM-dd HH:mm:ss} ==={Environment.NewLine}", Encoding.UTF8);
            LogLauncher($"Lancement du jeu : {GamePath}");

            var sessionId = Guid.NewGuid().ToString("N");
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
            process.OutputDataReceived += (_, e) => { if (e.Data != null) LogGame("STDOUT", e.Data); };
            process.ErrorDataReceived += (_, e) => { if (e.Data != null) LogGame("STDERR", e.Data); };
            process.Exited += async (_, _) => await HandleGameExitAsync(process, sessionId);

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            SetButtons(false);
            status.Text = "Infinite Ascension est lancé. Les logs sont enregistrés automatiquement.";
        }
        catch (Exception ex)
        {
            LogLauncher($"ERREUR lancement : {ex}");
            status.Text = $"Impossible de lancer le jeu : {ex.Message}";
            SetButtons(true);
        }
    }

    private async Task HandleGameExitAsync(Process process, string sessionId)
    {
        int exitCode = -1;
        try
        {
            // WaitForExit ensures asynchronous stdout/stderr events have been drained before reading the log.
            process.WaitForExit();
            exitCode = process.ExitCode;
            LogLauncher($"Jeu terminé avec code {exitCode}.");
            await UploadSessionLogAsync(sessionId, exitCode);
        }
        catch (Exception ex)
        {
            LogLauncher($"ERREUR fin de session : {ex}");
        }
        finally
        {
            process.Dispose();
            try
            {
                BeginInvoke(() =>
                {
                    if (IsDisposed) return;
                    status.Text = $"Jeu fermé · code {exitCode}. Logs enregistrés.";
                    SetButtons(true);
                });
            }
            catch { }
        }
    }

    private string? GetLogEndpoint()
    {
        var endpoint = Environment.GetEnvironmentVariable("INFINITE_ASCENSION_LOG_ENDPOINT");
        if (string.IsNullOrWhiteSpace(endpoint) && File.Exists(LogEndpointPath))
            endpoint = File.ReadAllText(LogEndpointPath, Encoding.UTF8).Trim();
        return string.IsNullOrWhiteSpace(endpoint) ? null : endpoint.Trim();
    }

    private async Task UploadSessionLogAsync(string sessionId, int exitCode)
    {
        var endpoint = GetLogEndpoint();
        if (string.IsNullOrWhiteSpace(endpoint))
        {
            LogLauncher("Upload des logs ignoré : endpoint non configuré.");
            return;
        }

        try
        {
            var log = File.Exists(GameLog) ? await File.ReadAllTextAsync(GameLog, Encoding.UTF8) : "";
            var payload = JsonSerializer.Serialize(new
            {
                build = LocalBuild(),
                session = sessionId,
                exitCode,
                launcherVersion = "5.0",
                os = Environment.OSVersion.VersionString,
                machine = Environment.MachineName,
                closedAtUtc = DateTimeOffset.UtcNow,
                log
            });

            using var content = new StringContent(payload, Encoding.UTF8, "application/json");
            using var request = new HttpRequestMessage(HttpMethod.Post, endpoint) { Content = content };
            request.Headers.UserAgent.ParseAdd("Infinite-Ascension-Launcher/5.0");
            using var response = await http.SendAsync(request);
            var responseText = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException($"HTTP {(int)response.StatusCode}: {responseText}");

            LogLauncher("Upload automatique du log réussi.");
        }
        catch (Exception ex)
        {
            // Logging must never prevent the player from closing the game/launcher.
            LogLauncher($"Upload automatique du log échoué : {ex.Message}");
        }
    }

    private void OpenLogs()
    {
        try
        {
            Directory.CreateDirectory(LogsDir);
            File.WriteAllText(Path.Combine(LogsDir, "README.txt"),
                "Infinite Ascension — journaux\r\n\r\n" +
                "launcher.log = journal du launcher\r\n" +
                "game.log = sortie stdout/stderr du jeu, utile pour diagnostiquer les erreurs Godot\r\n\r\n" +
                "L'upload automatique est configuré via INFINITE_ASCENSION_LOG_ENDPOINT ou log_endpoint.txt.\r\n", Encoding.UTF8);
            Process.Start(new ProcessStartInfo { FileName = "explorer.exe", Arguments = $"\"{LogsDir}\"", UseShellExecute = true });
        }
        catch (Exception ex)
        {
            LogLauncher($"ERREUR ouverture logs : {ex}");
        }
    }

    private void SetButtons(bool enabled)
    {
        play.Enabled = enabled;
        update.Enabled = enabled;
        logs.Enabled = true;
    }
}
