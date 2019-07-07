using System;
using System.Threading.Tasks;
using WalletGenerator.CommandLine;

namespace WalletGenerator
{
  class Program
  {
    static async Task Main(string[] args)
    {
      await CommandInterpreter.ExecuteCommandsAsync(args);
    }
  }
}
