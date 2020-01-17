const App = require( './lib/app.js' );

const main = async ( args ) => {
  const app = new App();
  const noWizard = args.indexOf('recreate') !== -1;
  await app.start(  {
    noWizard: noWizard,
    noSplashScreen: noWizard
  } );
};

main( process.argv.slice( 2, process.argv.length ) );
