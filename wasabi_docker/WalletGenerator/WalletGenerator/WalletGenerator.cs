using System;
using System.Threading;
using System.Threading.Tasks;
using System.Collections.Specialized;
using System.IO;
using System.Text;
using System.Collections.Concurrent;
using System.Collections.Generic;

using Newtonsoft.Json;

using NBitcoin;
using WalletWasabi.Helpers;
using WalletWasabi.KeyManagement;
using WalletWasabi.Models;
using WalletWasabi.Logging;
namespace WalletGenerator
{
  class WalletGenerator
  {

    public static string DataDir = GetDataDir();
    public static string WalletsDir = GetDataDir( "Wallets" );
    public static string WalletBackupsDir = GetDataDir( "WalletBackups" );

    public static string GetDataDir(string appName = "")
    {
      string directory;

      var localAppData = Environment.GetEnvironmentVariable("APPDATA");
      if (!string.IsNullOrEmpty(localAppData))
      {
        directory = Path.Combine(localAppData, appName);
      }
      else
      {
        throw new DirectoryNotFoundException("Could not find suitable datadir.");
      }

      if (Directory.Exists(directory))
      {
        return directory;
      }

      Directory.CreateDirectory(directory);

      return directory;
    }

    public static KeyManager TryGetKeymanagerFromWalletName(string walletName)
    {
      try
      {
        KeyManager keyManager = null;
        if (walletName != null)
        {
          var walletFullPath = GetWalletFullPath(walletName);
          var walletBackupFullPath = GetWalletBackupFullPath(walletName);
          if (!File.Exists(walletFullPath) && !File.Exists(walletBackupFullPath))
          {
            // The selected wallet is not available any more (someone deleted it?).
            Logger.LogCritical("The selected wallet doesn't exsist, did you delete it?");
            return null;
          }

          try
          {
            keyManager = LoadKeyManager(walletFullPath, walletBackupFullPath);
          }
          catch (Exception ex)
          {
            Logger.LogCritical(ex, nameof(Program));
            return null;
          }
        }

        if (keyManager is null)
        {
          Logger.LogCritical("Wallet was not supplied. Add --wallet:WalletName", nameof(Program));
          return null;
        }

        return keyManager;
      }
      catch (Exception ex)
      {
        Logger.LogCritical(ex, nameof(Program));
        return null;
      }
    }

    static string GetWalletFullPath(string walletName)
    {
      walletName = walletName.TrimEnd(".json", StringComparison.OrdinalIgnoreCase);
      return Path.Combine(WalletsDir, walletName + ".json");
    }

    static string GetWalletBackupFullPath(string walletName)
    {
      walletName = walletName.TrimEnd(".json", StringComparison.OrdinalIgnoreCase);
      return Path.Combine(WalletBackupsDir, walletName + ".json");
    }

    static KeyManager LoadKeyManager(string walletFullPath, string walletBackupFullPath)
    {
      try
      {
        return LoadKeyManager(walletFullPath);
      }
      catch (Exception ex)
      {
        if (!File.Exists(walletBackupFullPath))
        {
          throw;
        }

        Logger.LogWarning($"Wallet got corrupted.\n" +
                          $"Wallet Filepath: {walletFullPath}\n" +
                          $"Trying to recover it from backup.\n" +
                          $"Backup path: {walletBackupFullPath}\n" +
                          $"Exception: {ex.ToString()}");
        if (File.Exists(walletFullPath))
        {
          string corruptedWalletBackupPath = Path.Combine(WalletBackupsDir, $"{Path.GetFileName(walletFullPath)}_CorruptedBackup");
          if (File.Exists(corruptedWalletBackupPath))
          {
            File.Delete(corruptedWalletBackupPath);
            Logger.LogInfo($"Deleted previous corrupted wallet file backup from {corruptedWalletBackupPath}.");
          }
          File.Move(walletFullPath, corruptedWalletBackupPath);
          Logger.LogInfo($"Backed up corrupted wallet file to {corruptedWalletBackupPath}.");
        }
        File.Copy(walletBackupFullPath, walletFullPath);

        return LoadKeyManager(walletFullPath);
      }
    }

    public static KeyManager LoadKeyManager(string walletFullPath)
    {
      KeyManager keyManager;

      // Set the LastAccessTime.
      new FileInfo(walletFullPath)
      {
        LastAccessTime = DateTime.Now
      };

      keyManager = KeyManager.FromFile(walletFullPath);
      Logger.LogInfo($"Wallet loaded: {Path.GetFileNameWithoutExtension(keyManager.FilePath)}.");
      return keyManager;
    }

  }
}
