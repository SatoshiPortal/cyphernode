
invoke_cyphernode
{
	id="001";h64=$(echo "{\"alg\":\"HS256\",\"typ\":\"JWT\"}" | base64);p64=$(echo "{\"id\":\"$id\",\"exp\":$((`date +\"%s\"`+10))}" | base64);k="2df1eeea370eacdc5cf7e96c2d82140d1568079a5d4d87006ec8718a98883b36";s=$(echo "$h64.$p64" | openssl dgst -hmac "$k" -sha256 -r | cut -sd ' ' -f1);token="$h64.$p64.$s";curl -v -H "Authorization: Bearer $token" localhost/getbestblockhash

}
