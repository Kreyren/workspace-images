FROM exherbo/exherbo-x86_64-pc-linux-gnu-base

ENV LANG=en_US.UTF-8

# Add 'gitpod' user
RUN useradd \
	--uid 33333 \
	--groups sudo \
	--create-home --home-dir /home/gitpod \
	--shell /bin/bash \
	--password gitpod \
	gitpod || exit 1