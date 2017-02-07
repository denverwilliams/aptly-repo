



aptly -architectures="amd64" mirror create trusty-main http://nz.archive.ubuntu.com/ubuntu/ trusty main universe multiverse restricted
aptly -architectures="amd64" mirror create trusty-updates http://nz.archive.ubuntu.com/ubuntu/ trusty-updates main universe multiverse restricted
aptly -architectures="amd64" mirror create trusty-security http://nz.archive.ubuntu.com/ubuntu/ trusty-security main universe multiverse restricted

aptly mirror update trusty-main
aptly mirror update trusty-updates
aptly mirror update trusty-security

aptly snapshot create trusty-main from mirror trusty-main
aptly snapshot create trusty-updates from mirror trusty-updates
aptly snapshot create trusty-security from mirror trusty-security

aptly snapshot merge ubuntu-trusty trusty-main trusty-updates trusty-security

aptly -distribution=ubuntu publish snapshot ubuntu-trusty ubuntu






aptly mirror list -raw | xargs -n 1 aptly mirror update
