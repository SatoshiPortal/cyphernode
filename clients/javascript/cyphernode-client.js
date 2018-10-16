CyphernodeClient = function(is_prod) {
	this.baseURL = is_prod ? 'https://cyphernode:443' : 'https://cyphernode-dev:443'
  this.h64 = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9Cg=='
  this.api_key = Meteor.settings.CYPHERNODE.api_key
};

CyphernodeClient.prototype._post = function(url, postdata, cb) {
	let urlr = this.baseURL + url;

  let current = Math.round(new Date().getTime/1000) + 10
	let p64 = btoa('{"id":"${id}","exp":' + current + '}')
  let s = CryptoJS.HmacSHA256(p64, this.api_key).toString()
	let token = this.h64 + '.' + p64 + '.' + s

	HTTP.post(
		urlr,
		{
      data: postdata,
      headers: {'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + token},
    }, function (err, resp) {
			cb(err, resp.data)
		}
	)
};

CyphernodeClient.prototype._get = function(url, cb) {
	let urlr = this.baseURL + url;

  let current = Math.round(new Date().getTime/1000) + 10
	let p64 = btoa('{"id":"${id}","exp":' + current + '}')
  let s = CryptoJS.HmacSHA256(p64, this.api_key).toString()
	let token = this.h64 + '.' + p64 + '.' + s

	HTTP.get(urlr, {headers: {'Authorization': 'Bearer ' + token}}, function (err, resp) {
		cb(err, resp.data)
	})
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
