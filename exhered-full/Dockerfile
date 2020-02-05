FROM exherbo/exherbo-x86_64-pc-linux-gnu-base:latest

USER root

ENV LANG=en_US.UTF-8

# Add 'gitpod' user
## gitpod group already exists?
RUN { useradd \
	--uid 33333 \
	--create-home --home-dir /home/gitpod \
        --groups gitpod \
	--shell /bin/bash \
	--password gitpod \
	gitpod || exit 1 ;}
