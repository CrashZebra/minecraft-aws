#!/bin/sh

case $VERSION in
  LATEST)
    export VERSION=`wget -O - https://s3.amazonaws.com/Minecraft.Download/versions/versions.json | jsawk -n 'out(this.latest.release)'`
    ;;

  SNAPSHOT)
    export VERSION=`wget -O - https://s3.amazonaws.com/Minecraft.Download/versions/versions.json | jsawk -n 'out(this.latest.snapshot)'`
    ;;
esac

cd /data

if [ ! -e minecraft_server.$VERSION.jar ]; then
  echo "Downloading minecraft_server.$VERSION.jar ..."
  wget -q https://s3.amazonaws.com/Minecraft.Download/versions/$VERSION/minecraft_server.$VERSION.jar
fi

if [ ! -e server.properties ]; then
  cp /tmp/server.properties .
fi

if [ -n "$MOTD" ]; then
  sed -i "/motd\s*=/ c motd=$MOTD" /data/server.properties
fi
if [ -n "$LEVEL" ]; then
  sed -i "/level-name\s*=/ c level-name=$LEVEL" /data/server.properties
fi
if [ -n "$OPS" ]; then
  echo $OPS | awk -v RS=, '{print}' >> ops.txt
fi

if [ ! -e /data/eula.txt ]; then
  if [ "$EULA" != "" ]; then
    echo "# Generated via Docker on $(date)" > eula.txt
    echo "eula=$EULA" >> eula.txt
  else
    echo ""
    echo "Please accept the Minecraft EULA at"
    echo "  https://account.mojang.com/documents/minecraft_eula"
    echo "by adding the following immediately after 'docker run':"
    echo "  -e EULA=TRUE"
    echo ""
    exit 1
  fi
fi

java $JVM_OPTS -jar minecraft_server.$VERSION.jar
