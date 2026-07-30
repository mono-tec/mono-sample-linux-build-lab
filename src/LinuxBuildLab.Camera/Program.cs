using System.Diagnostics;

const string defaultDevice = "/dev/video0";
const string defaultOutput = "/var/lib/linux-build-lab-camera/capture.jpg";

string device = args.Length >= 1 ? args[0] : defaultDevice;
string outputPath = args.Length >= 2 ? args[1] : defaultOutput;

Console.WriteLine("========================================");
Console.WriteLine("Linux Build Lab Camera Sample");
Console.WriteLine("========================================");
Console.WriteLine($"実行日時 : {DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss zzz}");
Console.WriteLine($"Device   : {device}");
Console.WriteLine($"Output   : {outputPath}");

if (!OperatingSystem.IsLinux())
{
    Console.Error.WriteLine("[ERROR] このサンプルはLinux上で実行してください。");
    return 1;
}

if (!File.Exists(device))
{
    Console.Error.WriteLine($"[ERROR] カメラデバイスが見つかりません: {device}");
    return 2;
}

string? outputDirectory = Path.GetDirectoryName(outputPath);
if (string.IsNullOrWhiteSpace(outputDirectory))
{
    Console.Error.WriteLine("[ERROR] 出力先ディレクトリを判定できません。");
    return 3;
}

Directory.CreateDirectory(outputDirectory);

var startInfo = new ProcessStartInfo
{
    FileName = "v4l2-ctl",
    RedirectStandardOutput = true,
    RedirectStandardError = true,
    UseShellExecute = false
};

startInfo.ArgumentList.Add($"--device={device}");
startInfo.ArgumentList.Add("--set-fmt-video=width=640,height=480,pixelformat=MJPG");
startInfo.ArgumentList.Add("--set-parm=30");
startInfo.ArgumentList.Add("--stream-mmap");
startInfo.ArgumentList.Add("--stream-skip=10");
startInfo.ArgumentList.Add("--stream-count=1");
startInfo.ArgumentList.Add($"--stream-to={outputPath}");

Console.WriteLine("[INFO] v4l2-ctlを実行します。");

using Process process = new() { StartInfo = startInfo };

try
{
    process.Start();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"[ERROR] v4l2-ctlを起動できませんでした: {ex.Message}");
    return 4;
}

Task<string> stdoutTask = process.StandardOutput.ReadToEndAsync();
Task<string> stderrTask = process.StandardError.ReadToEndAsync();

await process.WaitForExitAsync();

string stdout = await stdoutTask;
string stderr = await stderrTask;

if (!string.IsNullOrWhiteSpace(stdout))
{
    Console.WriteLine(stdout.TrimEnd());
}

if (!string.IsNullOrWhiteSpace(stderr))
{
    Console.Error.WriteLine(stderr.TrimEnd());
}

if (process.ExitCode != 0)
{
    Console.Error.WriteLine($"[ERROR] v4l2-ctlが終了コード{process.ExitCode}で終了しました。");
    return 5;
}

if (!File.Exists(outputPath))
{
    Console.Error.WriteLine("[ERROR] 撮影後のJPEGファイルが見つかりません。");
    return 6;
}

long fileSize = new FileInfo(outputPath).Length;
if (fileSize <= 0)
{
    Console.Error.WriteLine("[ERROR] 作成されたJPEGファイルのサイズが0バイトです。");
    return 7;
}

Console.WriteLine($"[SUCCESS] JPEGファイルを作成しました。Size={fileSize} bytes");
Console.WriteLine("========================================");

return 0;
