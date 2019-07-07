using Mono.Options;
using System;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using WalletWasabi.Helpers;
using WalletWasabi.Logging;

namespace WalletGenerator.CommandLine
{
  public static class CommandInterpreter
  {
    /// <returns>If the GUI should run or not.</returns>
    public static async Task<bool> ExecuteCommandsAsync(string[] args)
    {
      var showHelp = false;

      OptionSet options = null;
      var suite = new CommandSet("walletgenerator") {
        "Does stuff around Wasabiwallet wallet file generation.",
        "",
        { "h|help", "Displays help page and exit.",
          x => showHelp = x != null
        },
        "",
        "Available commands are:",
        "",
        new CheckPasswordCommand(),
        new GenerateWalletCommand(),
        new PasswordFinderCommand()
      };

      EnsureBackwardCompatibilityWithOldParameters(ref args);
      if (await suite.RunAsync(args) == 0)
      {
        return false;
      }
      if (showHelp)
      {
        ShowHelp(options);
        return false;
      }

      return false;
    }

    private static void EnsureBackwardCompatibilityWithOldParameters(ref string[] args)
    {
      var listArgs = args.ToList();
      if (listArgs.Remove("--mix") || listArgs.Remove("-m"))
      {
        listArgs.Insert(0, "mix");
      }
      args = listArgs.ToArray();
    }

    private static void ShowHelp(OptionSet p)
    {
      Console.WriteLine();
      Console.WriteLine("Usage: wassabee [OPTIONS]+");
      Console.WriteLine("Launches Wasabi Wallet.");
      Console.WriteLine();
      Console.WriteLine("Options:");
      p.WriteOptionDescriptions(Console.Out);
    }
  }
}
