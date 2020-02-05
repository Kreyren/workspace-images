FROM exherbo/exherbo-x86_64-pc-linux-gnu-base:latest

# Exherbo image for gitpod	
# - Exherbo doesn't have addgroup -> Uses groupadd

USER root

ENV LANG=en_US.UTF-8

# Add 'gitpod' user
RUN addgroup() { exit 0 ;} ; { groupadd --gid 33333 gitpod || exit 1 ;} && \
	{ useradd \
	--uid 33333 \
	--create-home --home-dir /home/gitpod \
	--gid gitpod \
	--shell /bin/bash \
	--password gitpod \
	gitpod || exit 1 ;}
