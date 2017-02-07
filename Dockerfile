FROM debian:jessie
MAINTAINER Denver Williams (DLX)

ENV DEBIAN_FRONTEND noninteractive


# Instructions from: http://www.aptly.info/download/
RUN apt-get update && \
apt-get -y install wget gnupg xz-utils bzip2
RUN echo "deb http://repo.aptly.info/ squeeze main" > /etc/apt/sources.list.d/aptly.list
RUN wget -qO - https://www.aptly.info/pubkey.txt | apt-key add -

RUN apt-get update && \
apt-get install aptly -y

ADD files/aptly.conf /etc/aptly.conf
VOLUME ["/aptly"]

ADD files/public.key /gpgkeys/
ADD files/private.key /gpgkeys/
ADD files/aptly-mirror.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN gpg --allow-secret-key-import --import /gpgkeys/private.key
RUN gpg --import /gpgkeys/public.key
RUN echo DEBSIGN_KEYID=5AEFF845 > /etc/devscripts.conf

#Import ubuntu Keys
RUN gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver keys.gnupg.net --recv-keys 40976EAF437D05B5 3B4FE6ACC0B21F32

CMD []
#ENTRYPOINT ["/entrypoint.sh"]