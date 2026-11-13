#!/bin/bash
git init -q --bare "$FX/o.git" && git push -q "$FX/o.git" HEAD
