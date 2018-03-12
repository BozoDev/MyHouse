#!/bin/bash

[ -d /run/mqtt_listener ] || mkdir -p /run/mqtt_listener 2>/dev/null
chown mqtt-service /run/mqtt_listener

