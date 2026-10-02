FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_BASE_URL=/api

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
