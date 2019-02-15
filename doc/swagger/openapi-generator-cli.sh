#!/usr/bin/env bash


generators="ada \
ada-server \
android \
apache2 \
apex \
aspnetcore \
bash \
c \
clojure \
cwiki \
cpp-qt5-client \
cpp-qt5-qhttpengine-server \
cpp-pistache-server \
cpp-restbed-server \
cpp-restsdk \
cpp-tizen \
csharp \
csharp-refactor \
csharp-dotnet2 \
csharp-nancyfx \
dart \
dart-jaguar \
eiffel \
elixir \
elm \
erlang-client \
erlang-proper \
erlang-server \
flash \
scala-finch \
go \
go-server \
go-gin-server \
graphql-schema \
graphql-nodejs-express-server \
groovy \
kotlin \
kotlin-server \
kotlin-spring \
haskell-http-client \
haskell \
java \
jaxrs-cxf-client \
java-inflector \
java-msf4j \
java-pkmst \
java-play-framework \
java-undertow-server \
java-vertx \
jaxrs-cxf \
jaxrs-cxf-cdi \
jaxrs-jersey \
jaxrs-resteasy \
jaxrs-resteasy-eap \
jaxrs-spec \
javascript \
javascript-flowtyped \
javascript-closure-angular \
jmeter \
lua \
mysql-schema \
nodejs-server \
objc \
openapi \
openapi-yaml \
perl \
php \
php-laravel \
php-lumen \
php-slim \
php-silex \
php-symfony \
php-ze-ph \
powershell \
python \
python-flask \
python-aiohttp \
r \
ruby \
ruby-on-rails \
ruby-sinatra \
rust \
rust-server \
scalatra \
scala-akka \
scala-httpclient \
scala-gatling \
scala-lagom-server \
scalaz \
spring \
dynamic-html \
html \
html2 \
swift2-deprecated \
swift3-deprecated \
swift4 \
typescript-angular \
typescript-angularjs \
typescript-aurelia \
typescript-axios \
typescript-fetch \
typescript-inversify \
typescript-jquery \
typescript-node \
typescript-rxjs"

[[ $generators =~ (^|[[:space:]])$2($|[[:space:]]) ]] && echo 'Generator found' || (echo "No such generator" && exit)


if [[ ! -e $1 ]]; then
  mkdir `pwd`/$2
fi

docker run --rm -v `pwd`:/generator openapitools/openapi-generator-cli generate -o /generator/$2 -i /generator/$1 -g $2