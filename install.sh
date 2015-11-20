#!/bin/sh

PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAyTUJfAeSIe3vPrpMZDIF7KDYGVdEbVYHEXTtAH1Tfwl2w0R6vuyvG3upW5qSbrBgcp1g+N/WWjE0nlenlaoiDdAWVUb74NKTmiff/pgzshzcINv81bVshYZsNHvp6zms0uzxktnLjndzgP7mr0fVFKAiEBVV8UFVolo8skJW8d2GMRU06GFO+RePqaS3kt/y1LXTcZb56mt3vl8R5jvxDAGccB8gOakFSkVuY15PheHES5tzqOTLsznpFQjJBu08yyvdbFR6v4BA0OZY5QAOutt0H654QW521UrItjJ9OeSSTj/s4t0D55eMF5JAkHPi0gDqImD2zJ5y9KFdQlnfBQ== dedi.laxis.it"

apt-get update
AVAILABLE_KERNELS=$(apt-cache search linux-generic-lts | awk '{print $1}' | sed -e 's/^linux-generic-lts-//' -e '/-/ d' | tr '\n' ' ')

#apt-get -y install linux-generic-lts-

rm /etc/localtime && ln -s /usr/share/zoneinfo/CET /etc/localtime
locale-gen; update-locale LANG=en_US.UTF-8

