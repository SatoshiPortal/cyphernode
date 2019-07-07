using Mono.Options;
using NBitcoin;
using System;
using System.IO;
using System.Collections.Generic;
using System.Threading.Tasks;
using WalletWasabi.Helpers;
using WalletWasabi.KeyManagement;

namespace WalletGenerator.CommandLine
{
  internal class CheckPasswordCommand : Command
  {
    public string WalletName { get; set; }
    public string Password { get; set; }
    public bool ShowHelp { get; set; }

    public CheckPasswordCommand()
    : base("check", "Check password of a wallet file.")
    {
      Options = new OptionSet() {
        "usage: check --wallet:WalletName",
        "",
        "Checks the password of a wallet file",
        "eg: echo -n \"password\" | ./walletgenerator check --wallet:MyWalletName",
        "",
        { "w|wallet=", "The name of the wallet file.",
          x =>  WalletName = x
        },
        { "h|help", "Show Help",
          v => ShowHelp = true
        }
      };
    }

    public override Task<int> InvokeAsync(IEnumerable<string> args)
    {
      var passwordCorrect = false;
      try
      {
        var extra = Options.Parse(args);
        if (ShowHelp)
        {
          Options.WriteOptionDescriptions(CommandSet.Out);
        }
        else if (string.IsNullOrWhiteSpace(WalletName) )
        {
          Console.Error.WriteLine("Missing required argument `--wallet=WalletName`.");
          Console.Error.WriteLine("Use `check --help` for details.");
        }
        else
        {
          // Generate here
          try {

            string s = "";
            string password = "";
            while ((s = Console.ReadLine()) != null)
            {
              password += s;
            }

            password = Guard.Correct(password);

            string filePath = Path.Combine( WalletGenerator.WalletsDir, WalletName + ".json" );
            var manager = WalletGenerator.TryGetKeymanagerFromWalletName( WalletName );

            if ( manager == null ) {
              Console.Error.WriteLine( "No such wallet" );
            }


            if ( manager.TestPassword( password ) ) {
              passwordCorrect = true;
            }

          } catch ( Exception ) {
            Console.Error.WriteLine($"There was a problem checking the password.");
          }

        }
      }
      catch (Exception)
      {
        Console.Error.WriteLine($"There was a problem interpreting the command, please review it.");
      }
      Environment.Exit(passwordCorrect ? 0 : 1);
      Console.WriteLine(passwordCorrect ? "correct" : "wrong");
      return Task.FromResult(0);
    }
  }
}
