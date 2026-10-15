# Roadmap

Changes to the specs that wait for something upstream.

- **delta, musl on arm64:** delta has no musl build for arm64, so `specs/delta.toml` lacks
  `musl_arm64`. When [dandavison/delta#2268](https://github.com/dandavison/delta/pull/2268) is
  merged and a release has the asset, add `musl_arm64` to `[assets]` (likely
  `delta-{{ tag }}-aarch64-unknown-linux-musl.tar.gz`, once the release shows its name), and
  remove the note on it in the first comment of the spec. Then, like `hyperfine`, the glibc
  entries could use the musl builds, if the min glibc of the gnu builds is a problem.
