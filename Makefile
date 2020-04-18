# This is a helper for development of dockerimages

all:
	@ exit 2

debian:
	@ cat dockerfiles/core/debian.Dockerfile > temporary.Dockerfile
	@ cat dockerfiles/default/append-dockerfile.Dockerfile >> temporary.Dockerfile

test-thealer:
	@ gp preview about:blank && git add * && git commit -m "$$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c10)" && git push && gp preview https://gitpod.io/#https://github.com/Kreyren/workspace-images/pull/1