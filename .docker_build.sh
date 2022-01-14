#!/bin/bash
docker build --pull -t ${PWD##*/}:$USER .
