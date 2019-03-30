const exec = require('child_process').exec;

module.exports = async ( password ) => {

  if( !password ) {
    return null;
  }

  return await new Promise( (resolve) => {
    exec('htpasswd -bnB admin '+password+' | cut -sd \':\' -f2', (error, stdout, stderr) => {
      if (error) {
        return resolve(null);
      }
      // remove newline at the end
      resolve(stdout.substr(0,stdout.length-1));
    });
  });


};

