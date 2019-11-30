/*
 * MIT License
 *
 * Copyright (c) 2019 kexkey
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILIT * Y, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

package main

import (
	"bytes"
	"encoding/base32"
	"fmt"
	"os"
	"path"
	"strings"

	"crypto/ed25519"
	"crypto/sha512"

	"golang.org/x/crypto/sha3"
)

func main() {

	path := path.Clean(os.Args[1])
	fmt.Println("path=" + path)

	/**
		About the key files format: https://gitweb.torproject.org/tor.git/tree/src/lib/crypt_ops/crypto_format.c?h=tor-0.4.1.6#n34

		Write the <b>datalen</b> bytes from <b>data</b> to the file named
		<b>fname</b> in the tagged-data format.  This format contains a
		32-byte header, followed by the data itself.  The header is the
		NUL-padded string "== <b>typestring</b>: <b>tag</b> ==".  The length
		of <b>typestring</b> and <b>tag</b> must therefore be no more than
		24.

		About the secret key format: https://gitweb.torproject.org/tor.git/tree/src/lib/crypt_ops/crypto_ed25519.h?h=tor-0.4.1.6#n29

		Note that we store secret keys in an expanded format that doesn't match
		the format from standard ed25519.  Ed25519 stores a 32-byte value k and
		expands it into a 64-byte H(k), using the first 32 bytes for a multiplier
		of the base point, and second 32 bytes as an input to a hash function
		for deriving r.  But because we implement key blinding, we need to store
		keys in the 64-byte expanded form.
	**/

	// Key pair generation
	fmt.Println("Generating ed25519 keys...")
	publicKey, privateKey, _ := ed25519.GenerateKey(nil)

	// Convert seed to expanded private key...
	// Ref.: https://gitweb.torproject.org/tor.git/tree/src/ext/ed25519/donna/ed25519_tor.c?h=tor-0.4.1.6#n61
	// Ref.: https://gitweb.torproject.org/tor.git/tree/src/ext/curve25519_donna/README?h=tor-0.4.1.6#n28
	fmt.Println("Converting keys for TOR...")
	h := sha512.Sum512(privateKey[:32])
	h[0] &= 248
	h[31] &= 127
	h[31] |= 64

	// Create the Tor Hidden Service private key file
	fmt.Println("Creating secret file...")
	var fileBytes bytes.Buffer
	fileBytes.Write([]byte("== ed25519v1-secret: type0 =="))
	fileBytes.Write(bytes.Repeat([]byte{0x00}, 3))
	fileBytes.Write(h[:])

	prvFile, _ := os.Create(path + "/hs_ed25519_secret_key")
	fileBytes.WriteTo(prvFile)
	prvFile.Close()

	// Create the Tor Hidden Service public key file
	fmt.Println("Creating public file...")
	fileBytes.Reset()
	fileBytes.Write([]byte("== ed25519v1-public: type0 =="))
	fileBytes.Write(bytes.Repeat([]byte{0x00}, 3))
	fileBytes.Write([]byte(publicKey))

	pubFile, _ := os.Create(path + "/hs_ed25519_public_key")
	fileBytes.WriteTo(pubFile)
	pubFile.Close()

	// From https://github.com/rdkr/oniongen-go
	// checksum = H(".onion checksum" || pubkey || version)
	fmt.Println("Creating onion address...")
	var checksumBytes bytes.Buffer
	checksumBytes.Write([]byte(".onion checksum"))
	checksumBytes.Write([]byte(publicKey))
	checksumBytes.Write([]byte{0x03})
	checksum := sha3.Sum256(checksumBytes.Bytes())

	// onion_address = base32(pubkey || checksum || version)
	var onionAddressBytes bytes.Buffer
	onionAddressBytes.Write([]byte(publicKey))
	onionAddressBytes.Write([]byte(checksum[:2]))
	onionAddressBytes.Write([]byte{0x03})
	onionAddress := base32.StdEncoding.EncodeToString(onionAddressBytes.Bytes())

	// Create the Tor Hidden Service hostname file
	fmt.Println("Creating onion address file...")
	nameFile, _ := os.Create(path + "/hostname")
	nameFile.WriteString(strings.ToLower(onionAddress) + ".onion\n")
	nameFile.Close()

	fmt.Println("Done!")

}
