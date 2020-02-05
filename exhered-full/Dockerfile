FROM exherbo/exherbo-x86_64-pc-linux-gnu-base:latest

# Exherbo image for gitpod	
# - Exherbo doesn't have addgroup -> Uses groupadd

USER root

ENV LANG=en_US.UTF-8

# FOR THE EMPIRE! (https://github.com/gitpod-io/gitpod/issues/1179#issuecomment-582038789)
RUN for cmds in addgroup dpkg-query apt-get apk; do printf '%s\n' "# Added to pass gitpod build process" "exit 0" > "/usr/bin/$cmds"; done

# Add 'gitpod' user
RUN { groupadd --gid 33333 gitpod || exit 1 ;} && \
	{ useradd \
	--no-log-init \
	--uid 33333 \
	--create-home --home-dir /home/gitpod \
	--gid gitpod \
	--shell /bin/bash \
	--password gitpod \
	gitpod || exit 1 ;} && { usermod -a -G gitpod gitpod || exit 1 ;}
