# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org).

## [Unreleased]

### Added
- `Weheat` client with one function per WeHeat third-party endpoint.
- `Weheat.Auth` Keycloak grants and `Weheat.Auth.TokenSource` with rotation callback.
- `Weheat.RateLimiter`, default 30 requests/hour, started by the application.
