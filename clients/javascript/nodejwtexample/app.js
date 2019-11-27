/*
This is a simple script that take the API doc of how to access the cyphernode API which can be found at the URL below and turns
into code, which I feel would make more sense to users who are looking to develop apps.

https://github.com/SatoshiPortal/cyphernode/tree/master/doc


So what we are dealing with is this mother of a command that we can run from terminal and though it does work.  I scracthed my
head for several weeks tryinf to figure out what it actually did. In the end when I actually had to use my cyphernode I figured
it would be best if we actually decoded this so we could use it in node.  This script is the result of thos work and hopefully
it will allow future dumb coders like myself to progress a little faster :]

This the main command and basically what it is doing the following

1) creating an algo type and storing it in a a var called h64
2) creating a payload with ID and an expiry date in it and storing this in P64
3) setting the cyphernode api key as the secret and storing it in a variable called k
4) creating a SH!256 has from the above and storing it in a var called s
5) joining the h64,p64 and s vars together to create a JWT token
6) sending this to cyphernode proxy for processing


id="003";h64=$(echo -n "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo -n "{\"id\":\"$id\",\"exp\":$((`date +"%s"`+10))}" | base64);k="b9b8d527a1a27af2ad1697db3521f883760c342fc386dbc42c4efbb1a4d5e0af";s=$(echo -n "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Content-Type: application/json" -d '{"hash":"123","callbackUrl":"http://callback"}' -H "Authorization: Bearer $token" -k https://127.0.0.1:2009/v0/ots_stamp


As you see the code below breaks the above command down and refactors it into the code that can be used in node.js

Note, if you have not set up the SSL correctly you will have to override it by running the follwoing command
DEBUG=* NODE_TLS_REJECT_UNAUTHORIZED=0 node app.js or set it as an env file using sometjing like dotenv

*/
/*
===========================
START OF JWT TOKEN CREATION
===========================
*/


//load request
const request = require('request');
//load cruytpo js
const cryptojs = require("crypto-js");
//set an expiry time for the tokens.  Not this should be much lower in production, like 100 seconds but for testing it is fine.
//note maybe this should be an env var
const expiryInSeconds = 36000;
//set your API key here 
const api_key = "75459c072c20d762997820c05671b678a5861b3ac8d068b38d88db0a1a4df62a";
//set your cyphernode URL 
const cyphernodeurl = "https://localhost:2009/v0/"
//create a bearer token
//build the data
//set an this the id of the key you want to use which can be found in cyphernode/gatekeeper/keys.properties 
id = "003";
//set the expiry time to a point in the future
exp = Math.round(new Date().getTime() / 1000) + expiryInSeconds;
//set the algo type we are going to use and base 64 it
h64 = Buffer.from(JSON.stringify({
    alg: "HS256",
    typ: "JWT"
})).toString("base64");
//set the payload and set it to h64
p64 = Buffer.from(JSON.stringify({
    id: id,
    exp: exp
})).toString("base64");
//join them together
msg = h64 + "." + p64;
//get a sha256 has or the h64,p64 and the API key (which is the secret in JWT world)
const hash = cryptojs.HmacSHA256(msg, api_key);
//create the JWT token
const token = h64 + "." + p64 + "." + hash
//output it 
console.log("token - " + token);
/*
===========================
END OF JWT TOKEN CREATION
===========================
*/
/*
====================================
START OF REQUEST TO CYPHERNODE PROXY 
====================================
*/
//set the menthod we want to call
const method = "ln_getinfo";
//set the body we want to send, this is not required for every method call but it does no harm to send it
const body = '{"hash":"123","callbackUrl":"http://callback"}';
//create the Bearer header
const authheaader = "Bearer " + token;
//create the options object
//note : does CYPHER_GATEWAY_URL have to be different from RPC host?
const options = {
    url: cyphernodeurl + method,
    headers: {
        'Authorization': authheaader
    },
    body: body
};
//create the call back
function callback(error, response, body) {
    if (!error && response.statusCode == 200) {
        const info = JSON.parse(body);
        //do stuff with the result
        console.log(body);
    } else {
        //you done messed up boi
        console.log(error)
    }
}
//make the calls
request.post(options, callback);
/*
====================================
END OF REQUEST TO CYPHERNODE PROXY 
====================================
*/