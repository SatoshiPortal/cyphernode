#!/bin/sh

. ./trace.sh
. ./responsetoclient.sh

status_page() {
  cat <<EOF > statuspage.html
<html>
<head>
</head>
<body>
Hello from Cyphernode!<p/>
EOF

  cat db/installation.json >> statuspage.html

  cat <<EOF >> statuspage.html
</body>
</html>
EOF

  htmlfile_response_to_client ./ statuspage.html
}
