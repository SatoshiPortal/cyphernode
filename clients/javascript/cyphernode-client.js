//var createHmac = require('create-hmac')
//var crypto = require("crypto");

CyphernodeClient = function(is_prod) {
  this.baseURL = is_prod ? 'https://cyphernode:443' : 'https://cyphernode-dev:443'
  this.h64 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9Cg=='
  this.api_id = Meteor.settings.CYPHERNODE.api_id
  this.api_key = Meteor.settings.CYPHERNODE.api_key
};

CyphernodeClient.prototype._generateToken = function() {
//  console.log("api_id=" + this.api_id)
//  console.log("api_key=" + this.api_key)

  let current = Math.round(new Date().getTime()/1000) + 10
  let p = '{"id":"' + this.api_id + '","exp":' + current + '}'
//  console.log("p=" + p)
  const re1 = /\+/g;
  const re2 = /\//g;
  const p64 = Buffer.from(p)
    .toString("base64")
    .replace(re1, "-")
    .replace(re2, "_")
    .split("=")[0];
  let msg = this.h64 + '.' + p64
//  console.log("msg=" + msg)
  const s = crypto
    .createHmac("sha256", this.apiKey)
    .update(msg)
    .digest("base64")
    .replace(re1, "-")
    .replace(re2, "_")
    .split("=")[0];
//  let s2 = createHmac('sha256', this.api_key).update(msg).digest('hex')
//  let s3 = crypto.createHmac('sha256', this.api_key).update(msg).digest('hex');
//  console.log("s=" + s)
//  console.log("s2=" + s2)
//  console.log("s3=" + s3)
  let token = msg + '.' + s
//  console.log("token=" + token)

  return token
}

CyphernodeClient.prototype._post = function(url, postdata, cb, addedOptions) {
  let urlr = this.baseURL + url;
  let httpOptions = {
    data: postdata,
    npmRequestOptions: {
      strictSSL: false,
      agentOptions: {
        rejectUnauthorized: false
      }
    },
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + this._generateToken()
    }
  }
  if (addedOptions) {
    Object.assign(httpOptions.npmRequestOptions, addedOptions)
  }

  HTTP.post(urlr, httpOptions,
    function (err, resp) {
//      console.log(err)
//      console.log(resp)
      cb(err, resp.data || resp.content)
    }
  )
};

CyphernodeClient.prototype._get = function(url, cb, addedOptions) {
  let urlr = this.baseURL + url;
  let httpOptions = {
    npmRequestOptions: {
      strictSSL: false,
      agentOptions: {
        rejectUnauthorized: false
      }
    },
    headers: {
      'Authorization': 'Bearer ' + this._generateToken()
    }
  }
  if (addedOptions) {
    Object.assign(httpOptions.npmRequestOptions, addedOptions)
  }

  HTTP.get(urlr, httpOptions,
    function (err, resp) {
//      console.log(err)
//      console.log(resp)
      cb(err, resp.data || resp.content)
    }
  )
};

CyphernodeClient.prototype.watch = function(btcaddr, cb0conf, cb1conf, cbreply) {
  // BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","unconfirmedCallbackURL":"192.168.122.233:1111/callback0conf","confirmedCallbackURL":"192.168.122.233:1111/callback1conf"}
  let data = { address: btcaddr, unconfirmedCallbackURL: cb0conf, confirmedCallbackURL: cb1conf }
  this._post('/watch', data, cbreply);
};

CyphernodeClient.prototype.unwatch = function(btcaddr, cbreply) {
  // 192.168.122.152:8080/unwatch/2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp
  this._get('/unwatch/' + btcaddr, cbreply);
};

CyphernodeClient.prototype.getActiveWatches = function(cbreply) {
  // 192.168.122.152:8080/getactivewatches
  this._get('/getactivewatches', cbreply);
};

CyphernodeClient.prototype.getTransaction = function(txid, cbreply) {
  // http://192.168.122.152:8080/gettransaction/af867c86000da76df7ddb1054b273ca9e034e8c89d049b5b2795f9f590f67648
  this._get('/gettransaction/' + txid, cbreply);
};

CyphernodeClient.prototype.spend = function(btcaddr, amnt, cbreply) {
  // BODY {"address":"2N8DcqzfkYi8CkYzvNNS5amoq3SbAcQNXKp","amount":0.00233}
  let data = { address: btcaddr, amount: amnt }
  this._post('/spend', data, cbreply);
};

CyphernodeClient.prototype.getBalance = function(cbreply) {
  // http://192.168.122.152:8080/getbalance
  this._get('/getbalance', cbreply);
};

CyphernodeClient.prototype.getNewAddress = function(cbreply) {
  // http://192.168.122.152:8080/getnewaddress
  this._get('/getnewaddress', cbreply);
};

CyphernodeClient.prototype.ots_stamp = function(hash, callbackUrl, cbreply) {
  // POST https://cyphernode/ots_stamp
  // BODY {"hash":"1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7","callbackUrl":"192.168.111.233:1111/callbackUrl"}
  let data = { hash: hash, callbackUrl: callbackUrl }
  this._post('/ots_stamp', data, cbreply);
};

CyphernodeClient.prototype.ots_getfile = function(hash, cbreply) {
  // http://192.168.122.152:8080/ots_getfile/1ddfb769eb0b8876bc570e25580e6a53afcf973362ee1ee4b54a807da2e5eed7

  // encoding: null is for HTTP get to not convert the binary data to the default encoding
  this._get('/ots_getfile/' + hash, cbreply, { encoding: null });
};
