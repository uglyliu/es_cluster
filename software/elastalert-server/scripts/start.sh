#!/bin/bash

NODE_PATH=~/software/elastalert-server BABEL_DISABLE_CACHE=1 node ~/software/elastalert-server/index.js | ~/software/elastalert-server/node_modules/.bin/bunyan -o short
